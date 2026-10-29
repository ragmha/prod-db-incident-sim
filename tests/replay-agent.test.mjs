import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  callsPath, invocation, loadHooks, parseHookOutput, replayCalls, summarize,
} from "../scripts/replay-agent.mjs";

const calls = JSON.parse(readFileSync(callsPath, "utf8"));
const destroy = calls.find((call) => call.id === "destroy-auto-approve");
const plan = calls.find((call) => call.id === "plan");

function workspace(files) {
  const directory = mkdtempSync(join(tmpdir(), "hook-replay-"));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(join(directory, path, ".."), { recursive: true });
    writeFileSync(join(directory, path), content);
  }
  return directory;
}
const hook = (script, extra = {}) => ({ type: "command", exec: process.execPath, args: [script], ...extra });

test("the incident's calls are well formed and cover both decisions", () => {
  const ids = new Set();
  for (const call of calls) {
    assert.ok(call.id && !ids.has(call.id), `duplicate or missing id: ${call.id}`);
    ids.add(call.id);
    assert.ok(["allow", "deny"].includes(call.expect), call.id);
    assert.ok(call.toolName && call.toolArgs && call.story, call.id);
  }
  assert.ok(calls.some((call) => call.expect === "deny") && calls.some((call) => call.expect === "allow"));
});

test("progress lines are ignored and exactly one decision object is read", () => {
  assert.deepEqual(parseHookOutput('{"type":"progress","message":"x"}\n{"permissionDecision":"deny"}'), { permissionDecision: "deny" });
  assert.equal(parseHookOutput(""), undefined);
  assert.equal(parseHookOutput('{"permissionDecision":"deny"}\n{"permissionDecision":"allow"}'), undefined);
  assert.equal(parseHookOutput("not json"), undefined);
});

test("hooks run the platform's command without a shell for exec entries", () => {
  assert.deepEqual(invocation({ bash: "a", powershell: "b" }, "linux"), { command: "bash", args: ["-c", "a"] });
  assert.equal(invocation({ bash: "a", powershell: "b" }, "win32").args.at(-1), "b");
  assert.deepEqual(invocation({ command: "c" }, "linux"), { command: "bash", args: ["-c", "c"] });
  assert.deepEqual(invocation({ exec: "node", args: ["x"] }, "linux"), { command: "node", args: ["x"] });
  assert.equal(invocation({ powershell: "b" }, "linux"), undefined);
});

test("with no hooks every call proceeds, which is unguarded", () => {
  const results = replayCalls([destroy, plan], []);
  assert.deepEqual(results.map((result) => result.actual), ["allow", "allow"]);
  assert.equal(summarize(results, 0).outcome, "unguarded");
});

test("a policy must deny both toolArgs shapes, and silence keeps the default flow", () => {
  const directory = workspace({
    "deny-destroy.mjs": `
      import { readFileSync } from "node:fs";
      const input = JSON.parse(readFileSync(0, "utf8"));
      const args = typeof input.toolArgs === "string" ? JSON.parse(input.toolArgs) : input.toolArgs;
      if (/terraform.*destroy/.test(args.command ?? "")) console.log(JSON.stringify({ permissionDecision: "deny", permissionDecisionReason: "no" }));`,
    "object-only.mjs": `
      import { readFileSync } from "node:fs";
      const input = JSON.parse(readFileSync(0, "utf8"));
      if (/destroy/.test(input.toolArgs?.command ?? "")) console.log(JSON.stringify({ permissionDecision: "deny", permissionDecisionReason: "no" }));`,
  });
  try {
    const guarded = replayCalls([destroy, plan], [hook(join(directory, "deny-destroy.mjs"))], { cwd: directory });
    assert.deepEqual(guarded.map((result) => result.actual), ["deny", "allow"]);
    assert.equal(summarize(guarded, 1).outcome, "guarded");
    const partial = replayCalls([destroy], [hook(join(directory, "object-only.mjs"))], { cwd: directory });
    assert.equal(partial[0].actual, "inconsistent");
    assert.equal(summarize(partial, 1).outcome, "leaky");
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("crashing hooks fail closed and timed-out hooks fail open, as in Copilot", () => {
  const directory = workspace({
    "crash.mjs": "process.exit(3);",
    "slow.mjs": "setTimeout(() => {}, 5000);",
  });
  try {
    const crashed = replayCalls([plan], [hook(join(directory, "crash.mjs"))], { cwd: directory });
    assert.equal(crashed[0].actual, "deny");
    assert.equal(summarize(crashed, 1).outcome, "overblocking");
    const slow = replayCalls([destroy], [hook(join(directory, "slow.mjs"), { timeoutSec: 1 })], { cwd: directory });
    assert.equal(slow[0].actual, "allow");
    assert.equal(slow[0].timedOut, true);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("hook files load like Copilot loads them, with warnings for ignored entries", () => {
  const directory = workspace({
    "hooks/a.json": JSON.stringify({ version: 1, hooks: { preToolUse: [{ type: "command", bash: "true" }] } }),
    "hooks/broken.json": "{",
    "hooks/pascal.json": JSON.stringify({ version: 1, hooks: { PreToolUse: [{ type: "command", bash: "true" }] } }),
    "hooks/http.json": JSON.stringify({ version: 1, hooks: { preToolUse: [{ type: "http", url: "https://example.test" }] } }),
  });
  try {
    const { hooks, warnings } = loadHooks(join(directory, "hooks"));
    assert.equal(hooks.length, 1);
    assert.equal(warnings.length, 3);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
