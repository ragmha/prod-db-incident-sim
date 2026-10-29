#!/usr/bin/env node
// Replays the incident's agent tool calls through the repository's Copilot
// preToolUse hooks (.github/hooks/*.json) and reports what each call would do.
//
// Hooks run the way Copilot CLI runs command hooks: the tool call arrives as
// JSON on stdin and the hook may print {"permissionDecision": "deny", ...}.
// A crash or non-zero exit denies the call (fail-closed); a timeout lets it
// through (fail-open). Each call is replayed with toolArgs both as an object
// and as a JSON string, so a policy must handle either shape.
//
//   node scripts/replay-agent.mjs [--json <file>] [--strict]
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
export const callsPath = join(root, "tests", "incident", "agent-tool-calls.json");

export function loadHooks(directory = join(root, ".github", "hooks")) {
  const hooks = [];
  const warnings = [];
  if (!existsSync(directory)) return { hooks, warnings };
  for (const file of readdirSync(directory).filter((name) => name.endsWith(".json")).sort()) {
    let config;
    try {
      config = JSON.parse(readFileSync(join(directory, file), "utf8"));
    } catch (error) {
      warnings.push(`${file}: invalid JSON, so Copilot ignores the whole file (${error.message}).`);
      continue;
    }
    if (config?.version !== 1 || !config.hooks || typeof config.hooks !== "object") {
      warnings.push(`${file}: needs "version": 1 and a "hooks" object.`);
      continue;
    }
    if (config.hooks.PreToolUse) {
      warnings.push(`${file}: PascalCase PreToolUse receives the VS Code payload and is not replayed; use preToolUse.`);
    }
    const entries = config.hooks.preToolUse ?? [];
    if (!Array.isArray(entries)) {
      warnings.push(`${file}: preToolUse must be an array.`);
      continue;
    }
    for (const entry of entries) {
      if ((entry?.type ?? "command") !== "command") {
        warnings.push(`${file}: only command hooks are replayed.`);
        continue;
      }
      hooks.push({ ...entry, file });
    }
  }
  return { hooks, warnings };
}

export function invocation(hook, platform = process.platform) {
  if (hook.exec) return { command: hook.exec, args: hook.args ?? [] };
  if (platform === "win32") {
    const script = hook.powershell ?? hook.command;
    return script ? { command: "powershell", args: ["-NoProfile", "-NonInteractive", "-Command", script] } : undefined;
  }
  const script = hook.bash ?? hook.command;
  return script ? { command: "bash", args: ["-c", script] } : undefined;
}

// Progress lines are removed; the rest of stdout must be one JSON object.
export function parseHookOutput(stdout = "") {
  const kept = stdout.split(/\r?\n/).filter((line) => {
    const text = line.trim();
    if (!text.startsWith("{")) return true;
    try {
      return JSON.parse(text)?.type !== "progress";
    } catch {
      return true;
    }
  }).join("\n").trim();
  if (!kept) return undefined;
  try {
    const value = JSON.parse(kept);
    return value && typeof value === "object" && !Array.isArray(value) ? value : undefined;
  } catch {
    return undefined;
  }
}

export function runHook(hook, input, { cwd = root, platform = process.platform } = {}) {
  const call = invocation(hook, platform);
  if (!call) return { decision: "skip", reason: "no command for this platform" };
  const seconds = hook.timeoutSec ?? hook.timeout ?? 30;
  const result = spawnSync(call.command, call.args, {
    cwd: hook.cwd ? resolve(cwd, hook.cwd) : cwd,
    env: { ...process.env, ...hook.env },
    input: JSON.stringify(input),
    encoding: "utf8",
    timeout: seconds * 1000,
    maxBuffer: 10 * 1024 * 1024,
  });
  if (result.error?.code === "ETIMEDOUT") {
    return { decision: "allow", timedOut: true, reason: `timed out after ${seconds}s: Copilot lets the call through` };
  }
  if (result.error) return { decision: "deny", reason: `could not start (${result.error.message}): fail-closed` };
  if (result.status !== 0) return { decision: "deny", reason: `exited with status ${result.status ?? result.signal}: fail-closed` };
  const output = parseHookOutput(result.stdout);
  const decision = output?.permissionDecision;
  if (!["allow", "deny", "ask"].includes(decision)) return { decision: "default", reason: "no decision" };
  return { decision, reason: output.permissionDecisionReason ?? "" };
}

function decide(results) {
  for (const decision of ["deny", "ask", "allow"]) {
    const match = results.find((result) => result.decision === decision);
    if (match) return match;
  }
  return { decision: "default", reason: "no hook decided" };
}

export function replayCalls(calls, hooks, options = {}) {
  return calls.map((call) => {
    const shapes = ["object", "string"].map((shape) => {
      const input = {
        sessionId: "incident-replay",
        timestamp: Date.now(),
        cwd: options.cwd ?? root,
        toolName: call.toolName,
        toolArgs: shape === "string" ? JSON.stringify(call.toolArgs) : call.toolArgs,
      };
      return { shape, ...decide(hooks.map((hook) => runHook(hook, input, options))) };
    });
    const denied = shapes.filter((shape) => shape.decision === "deny").length;
    const actual = denied === shapes.length ? "deny" : denied === 0 ? "allow" : "inconsistent";
    return {
      id: call.id, toolName: call.toolName, story: call.story, expect: call.expect, actual,
      pass: actual === call.expect,
      reason: shapes.find((shape) => shape.reason)?.reason ?? "",
      timedOut: shapes.some((shape) => shape.timedOut),
    };
  });
}

export function summarize(results, hookCount, warnings = []) {
  const leaks = results.filter((result) => result.expect === "deny" && !result.pass).map((result) => result.id);
  const overblocks = results.filter((result) => result.expect === "allow" && !result.pass).map((result) => result.id);
  const outcome = hookCount === 0 ? "unguarded" : leaks.length ? "leaky" : overblocks.length ? "overblocking" : "guarded";
  return { schemaVersion: 1, outcome, hooks: hookCount, calls: results.length, leaks, overblocks, warnings, results };
}

function describe(call) {
  const args = call.toolArgs ?? {};
  return args.command ?? args.path ?? JSON.stringify(args);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const argv = process.argv.slice(2);
  const jsonIndex = argv.indexOf("--json");
  const calls = JSON.parse(readFileSync(callsPath, "utf8"));
  const { hooks, warnings } = loadHooks();
  const results = replayCalls(calls, hooks);
  const summary = summarize(results, hooks.length, warnings);

  for (const warning of warnings) console.warn(`Warning: ${warning}`);
  console.log(`Replaying ${calls.length} agent tool calls through ${hooks.length} preToolUse hook(s).\n`);
  for (const [index, result] of results.entries()) {
    const mark = result.pass ? "ok  " : result.expect === "deny" ? "LEAK" : "OVER";
    console.log(`${mark}  ${result.actual.padEnd(12)} ${result.toolName.padEnd(10)} ${describe(calls[index])}`);
    if (!result.pass) console.log(`      expected ${result.expect}: ${result.story}`);
    if (result.timedOut) console.log("      the hook timed out, and timeouts fail open");
  }
  const messages = {
    unguarded: "No preToolUse hooks: every call goes through the normal permission prompt, as it did in the incident.",
    leaky: `Leaks: ${summary.leaks.join(", ")}. A destructive call would reach the shell.`,
    overblocking: `Over-blocking: ${summary.overblocks.join(", ")}. Safe work is denied; agents need room to plan and edit.`,
    guarded: "Guarded: every destructive call is denied and every safe call can proceed.",
  };
  console.log(`\n${messages[summary.outcome]}`);

  if (jsonIndex >= 0) {
    const file = resolve(argv[jsonIndex + 1] ?? "agent-replay.json");
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, `${JSON.stringify(summary, null, 2)}\n`);
  }
  if (argv.includes("--strict") && summary.outcome !== "guarded") process.exitCode = 1;
}
