#!/usr/bin/env node
// Combines the restore drill, incident replay, and agent replay results (plus
// the release record, when present) into lab-evidence.json, the file the
// exercise coach reads from CI and Release artifacts. Outside Actions it
// records a local identity, which the coach never accepts.
//
// With LAB_ENFORCE=true it fails when production would still be lost, the
// backup does not restore, or an agent's destructive call gets through: the
// incident becomes a regression test.
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export function buildEvidence(directory, env = process.env) {
  const read = (name) => JSON.parse(readFileSync(join(directory, name), "utf8"));
  const evidence = {
    schemaVersion: 1,
    repository: env.GITHUB_REPOSITORY ?? "local",
    sourceSha: env.GITHUB_SHA ?? "local",
    runId: Number(env.GITHUB_RUN_ID ?? 0),
    runAttempt: Number(env.GITHUB_RUN_ATTEMPT ?? 0),
    enforced: env.LAB_ENFORCE === "true",
    drill: read("drill.json"),
    incidentReplay: read("incident-replay.json"),
    agentReplay: read("agent-replay.json"),
  };
  if (existsSync(join(directory, "release.json"))) evidence.release = read("release.json");
  return evidence;
}

export function regressions({ drill, incidentReplay, agentReplay }) {
  const problems = [];
  if (drill?.outcome !== "restored") problems.push("the independent backup did not restore completely");
  if (incidentReplay?.outcome !== "blocked") problems.push(`the incident replay left production ${incidentReplay?.outcome}`);
  if (incidentReplay?.newLaptopPlan?.add !== 0) problems.push("a fresh clone still plans to create production again");
  if (agentReplay?.outcome !== "guarded") problems.push(`the agent replay was ${agentReplay?.outcome}`);
  return problems;
}

export function summaryMarkdown(evidence) {
  const { drill, incidentReplay: replay, agentReplay: agent } = evidence;
  return [
    "## Incident lab",
    "",
    "| Check | Result |",
    "| --- | --- |",
    `| Restore drill | ${drill.outcome}: ${drill.rowsRestored} of ${drill.rowsExpected} rows |`,
    `| Incident replay | production ${replay.outcome}; a fresh clone planned to add ${replay.newLaptopPlan.add} |`,
    `| Agent replay | ${agent.outcome}: ${agent.leaks.length} leaks, ${agent.overblocks.length} over-blocks |`,
    `| Regression gate | ${evidence.enforced ? "enforced" : "not enforced yet (Step 6)"} |`,
    "",
  ].join("\n");
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const directory = resolve(process.argv[2] ?? ".lab/evidence");
  const evidence = buildEvidence(directory);
  writeFileSync(join(directory, "lab-evidence.json"), `${JSON.stringify(evidence, null, 2)}\n`);
  const { drill, incidentReplay, agentReplay } = evidence;
  console.log(`Restore drill:   ${drill.outcome} (${drill.rowsRestored}/${drill.rowsExpected} rows)`);
  console.log(`Incident replay: production ${incidentReplay.outcome}; a fresh clone planned to add ${incidentReplay.newLaptopPlan.add}`);
  console.log(`Agent replay:    ${agentReplay.outcome} (${agentReplay.leaks.length} leaks, ${agentReplay.overblocks.length} over-blocks)`);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, summaryMarkdown(evidence));
  const problems = regressions(evidence);
  if (evidence.enforced && problems.length) {
    console.error(`Regression gate failed: ${problems.join("; ")}.`);
    process.exitCode = 1;
  }
}
