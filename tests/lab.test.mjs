import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { summarizePlan } from "../scripts/lab/plan-guard.mjs";
import { buildEvidence, regressions } from "../scripts/lab/evidence.mjs";

const change = (address, actions) => ({ address, change: { actions } });

test("the plan guard counts changes and flags deletions and replacements", () => {
  const update = summarizePlan({ resource_changes: [change("a.db", ["update"]), change("a.keep", ["no-op"])] });
  assert.deepEqual([update.add, update.change, update.destroy, update.deletions], [0, 1, 0, []]);
  assert.deepEqual(update.changes, ["a.db:update"]);
  const replace = summarizePlan({ resource_changes: [change("a.db", ["delete", "create"])] });
  assert.deepEqual(replace.deletions, ["a.db"]);
  assert.deepEqual(replace.changes, ["a.db:delete+create"]);
  assert.deepEqual(summarizePlan({}).changes, []);
});

test("evidence records the run identity, the gate, and an optional release", () => {
  const directory = mkdtempSync(join(tmpdir(), "lab-evidence-"));
  try {
    writeFileSync(join(directory, "drill.json"), '{"outcome":"restored","rowsExpected":5,"rowsRestored":5}');
    writeFileSync(join(directory, "incident-replay.json"), '{"outcome":"destroyed","newLaptopPlan":{"add":1}}');
    writeFileSync(join(directory, "agent-replay.json"), '{"outcome":"unguarded","leaks":[],"overblocks":[]}');
    const env = { GITHUB_REPOSITORY: "learner/repo", GITHUB_SHA: "abc", GITHUB_RUN_ID: "7", GITHUB_RUN_ATTEMPT: "2", LAB_ENFORCE: "true" };
    const evidence = buildEvidence(directory, env);
    assert.deepEqual([evidence.repository, evidence.sourceSha, evidence.runId, evidence.runAttempt, evidence.enforced],
      ["learner/repo", "abc", 7, 2, true]);
    assert.equal(evidence.release, undefined);
    assert.equal(regressions(evidence).length, 3);
    writeFileSync(join(directory, "release.json"), '{"applied":true,"plan":{"add":0,"change":1,"destroy":0}}');
    assert.equal(buildEvidence(directory, {}).release.applied, true);
    assert.equal(buildEvidence(directory, {}).enforced, false);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("a guarded lab has no regressions", () => {
  assert.deepEqual(regressions({
    drill: { outcome: "restored" },
    incidentReplay: { outcome: "blocked", newLaptopPlan: { add: 0 } },
    agentReplay: { outcome: "guarded" },
  }), []);
});
