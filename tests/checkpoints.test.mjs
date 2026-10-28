import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const {
  evaluateStep, reportProblems, evidenceProblems, releaseProblems, agentProblems, codeownersCovers,
  REPORTS, REQUIRED_AGENT_CASES,
} = createRequire(import.meta.url)("../.github/scripts/checkpoints.cjs");

const identity = { repository: "learner/repo", sha: "a".repeat(40), runId: 123, runAttempt: 1 };

function report(step) {
  return REPORTS[step][0][1].map((heading) =>
    `## ${heading}\nConcrete commands, outputs, row counts, and a deliberate human decision.`).join("\n\n");
}
function agentReplay(overrides = {}) {
  const results = Object.entries(REQUIRED_AGENT_CASES).map(([id, expect]) => ({ id, expect, actual: expect, pass: true }));
  return { schemaVersion: 1, outcome: "guarded", leaks: [], overblocks: [], results, ...overrides };
}
function evidence(overrides = {}) {
  return {
    schemaVersion: 1, repository: identity.repository, sourceSha: identity.sha,
    runId: identity.runId, runAttempt: identity.runAttempt, enforced: true,
    drill: { outcome: "restored", rowsExpected: 100, rowsRestored: 100 },
    incidentReplay: { outcome: "blocked", newLaptopPlan: { add: 0, change: 0, destroy: 0 } },
    agentReplay: agentReplay(),
    ...overrides,
  };
}
function context(files = {}, extra = {}) {
  return {
    readText: async (path) => files[path], listPaths: async () => Object.keys(files),
    ciPassed: true, evidence: evidence(), ...identity, ...extra,
  };
}
const guardrails = `terraform {
  backend "pg" {}
}
resource "terraform_data" "course_platform_db" {
  input = { name = "course_platform", delete_automated_backups = false }
  lifecycle {
    prevent_destroy = true
  }
}`;
const owners = "/infrastructure/ @learner\n/.github/ @learner\n";

test("reports need every heading and substantive, finished text", () => {
  const headings = REPORTS[1][0][1];
  assert.deepEqual(reportProblems("r.md", report(1), headings), []);
  assert.equal(reportProblems("r.md", undefined, headings).length, 1);
  assert.ok(reportProblems("r.md", `${report(1)}\nTBD`, headings).length);
  assert.ok(reportProblems("r.md", "## Timeline\nshort", headings).length);
});

test("analysis steps need their report and current CI, not runtime evidence", async () => {
  for (const step of [1, 3]) {
    const files = { [REPORTS[step][0][0]]: report(step) };
    assert.equal((await evaluateStep(step, context(files, { evidence: undefined }))).passed, true);
    assert.equal((await evaluateStep(step, context(files, { ciPassed: false }))).passed, false);
  }
});

test("recovery requires CI's drill to restore every row", async () => {
  const files = { "evidence/02-recovery.md": report(2) };
  assert.equal((await evaluateStep(2, context(files))).passed, true);
  const partial = evidence({ drill: { outcome: "restored", rowsExpected: 100, rowsRestored: 99 } });
  assert.equal((await evaluateStep(2, context(files, { evidence: partial }))).passed, false);
  assert.equal((await evaluateStep(2, context(files, { evidence: undefined }))).passed, false);
});

test("guardrails need the configuration, owners, and a blocked replay from CI", async () => {
  const files = { "evidence/04-guardrails.md": report(4), "infrastructure/lab/main.tf": guardrails, CODEOWNERS: owners };
  assert.equal((await evaluateStep(4, context(files))).passed, true);
  for (const [path, value] of [
    ["infrastructure/lab/main.tf", guardrails.replace("prevent_destroy = true", "prevent_destroy = false")],
    ["infrastructure/lab/main.tf", guardrails.replace('backend "pg" {}', "")],
    ["infrastructure/lab/main.tf", guardrails.replace("delete_automated_backups = false", "delete_automated_backups = true")],
    ["CODEOWNERS", "/infrastructure/ @learner\n"],
  ]) {
    assert.equal((await evaluateStep(4, context({ ...files, [path]: value }))).passed, false, value);
  }
  const destroyed = evidence({ incidentReplay: { outcome: "destroyed", newLaptopPlan: { add: 0 } } });
  assert.equal((await evaluateStep(4, context(files, { evidence: destroyed }))).passed, false);
  const freshClone = evidence({ incidentReplay: { outcome: "blocked", newLaptopPlan: { add: 1 } } });
  assert.equal((await evaluateStep(4, context(files, { evidence: freshClone }))).passed, false);
});

test("CODEOWNERS rules need a real owner and ignore comments", () => {
  assert.equal(codeownersCovers("/infrastructure/ @org/platform", /^\/?infrastructure\/?$/), true);
  assert.equal(codeownersCovers("# /infrastructure/ @me", /^\/?infrastructure\/?$/), false);
  assert.equal(codeownersCovers("/infrastructure/", /^\/?infrastructure\/?$/), false);
});

test("agent governance needs hooks, scoped instructions, an agent, and a guarded replay", async () => {
  const files = {
    "evidence/05-agent-hooks.md": report(5),
    ".github/hooks/guard.json": JSON.stringify({ version: 1, hooks: { preToolUse: [{ type: "command", bash: "node guard.mjs" }] } }),
    ".github/instructions/infrastructure.instructions.md": '---\napplyTo: "infrastructure/**"\n---\nPlan only.',
    ".github/agents/infra-operator.agent.md": "---\ndescription: Operate safely\ntools: [read, search]\n---\nAsk for approval.",
  };
  assert.equal((await evaluateStep(5, context(files))).passed, true);
  assert.equal((await evaluateStep(5, context({ ...files, ".github/hooks/guard.json": "{" }))).passed, false);
  const leaky = evidence({ agentReplay: agentReplay({ outcome: "leaky", leaks: ["destroy-wrapped"] }) });
  assert.equal((await evaluateStep(5, context(files, { evidence: leaky }))).passed, false);
});

test("the incident's own agent cases cannot be removed or flipped", () => {
  assert.deepEqual(agentProblems(agentReplay()), []);
  const results = agentReplay().results.filter((result) => result.id !== "destroy-auto-approve");
  assert.equal(agentProblems(agentReplay({ results })).length, 1);
  const flipped = agentReplay().results.map((result) => result.id === "drop-database" ? { ...result, expect: "allow" } : result);
  assert.equal(agentProblems(agentReplay({ results: flipped })).length, 1);
});

test("the coach accepts evidence only from the matching Actions run", () => {
  assert.deepEqual(evidenceProblems(evidence(), identity), []);
  for (const change of [{ sha: "b".repeat(40) }, { runId: 124 }, { runAttempt: 2 }, { repository: "fork/repo" }]) {
    assert.equal(evidenceProblems(evidence(), { ...identity, ...change }).length, 1);
  }
  const local = { ...evidence(), repository: "local", runId: 0, runAttempt: 0 };
  assert.equal(evidenceProblems(local, identity).length, 1);
  assert.deepEqual(evidenceProblems(local, { local: true }), []);
});

test("release needs the enforced gate, a compiled review, and an approved Release run", async () => {
  const review = "workflow_dispatch\ncontents: read\ncheckout: false\ntools:\n  bash: false\n  edit: false\n    read-only: true\nsafe-outputs:\n  create-issue:\n    max: 1\n";
  const files = {
    "evidence/06-release.md": report(6),
    ".github/workflows/guardrail-review.md": review,
    ".github/workflows/guardrail-review.lock.yml": "# gh-aw\nworkflow_dispatch",
  };
  const run = { id: 456, run_attempt: 1 };
  const releaseEvidence = evidence({ runId: 456, release: { applied: true, plan: { add: 0, change: 1, destroy: 0 } } });
  const approvals = [{ state: "approved", environments: [{ name: "production" }], user: { login: "learner" } }];
  const release = { run, approvals, evidence: releaseEvidence };
  assert.equal((await evaluateStep(6, context(files, { release }))).passed, true);
  assert.equal((await evaluateStep(6, context(files, { release, evidence: evidence({ enforced: false }) }))).passed, false);
  assert.equal((await evaluateStep(6, context(files, { release: {} }))).passed, false);
  assert.equal((await evaluateStep(6, context({ ...files, ".github/workflows/guardrail-review.md": review.replace("max: 1", "max: 5") }, { release }))).passed, false);
  assert.equal((await evaluateStep(6, context(files, { local: true, release: undefined }))).passed, true);

  assert.equal(releaseProblems({ ...release, approvals: [] }, identity).length, 1);
  assert.equal(releaseProblems({ ...release, approvals: [{ ...approvals[0], state: "rejected" }] }, identity).length, 1);
  assert.equal(releaseProblems({ ...release, evidence: evidence({ runId: 999 }) }, identity).length, 1);
  const deleting = evidence({ runId: 456, release: { applied: true, plan: { add: 0, change: 0, destroy: 1 } } });
  assert.equal(releaseProblems({ ...release, evidence: deleting }, identity).length, 1);
});

test("unknown checkpoints are explicit errors", async () => {
  await assert.rejects(() => evaluateStep(7, context()), /Unknown checkpoint/);
});
