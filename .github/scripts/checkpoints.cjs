// Checkpoint rules shared by the exercise coach (Actions) and `npm run checkpoint`.
// Reports are checked structurally; their substance is for you and your reviewer.
// Runtime claims come from CI and Release evidence artifacts, never from learner text.

const REPORTS = {
  1: [["evidence/01-incident.md", ["Timeline", "What Terraform believed", "Blast radius", "Where it could have stopped"]]],
  2: [["evidence/02-recovery.md", ["Automated backups", "Restore", "RTO and RPO", "Drill"]]],
  3: [["evidence/03-postmortem.md", ["Summary", "Contributing factors", "Guardrail plan", "Human approval"]]],
  4: [["evidence/04-guardrails.md", ["Agent work", "Human review", "Replay result"]]],
  5: [["evidence/05-agent-hooks.md", ["Hook policy", "Replay result", "What hooks do not cover"]]],
  6: [["evidence/06-release.md", ["Regression gate", "Release", "Agentic review", "Human decision"]]],
};

// The incident's own tool calls. They must stay in the replay with these
// expectations; you may add cases, but not remove or flip these.
const REQUIRED_AGENT_CASES = {
  "apply-auto-approve": "deny", "unpack-old-state": "deny", "copy-old-state": "deny",
  "edit-state": "deny", "destroy-auto-approve": "deny", "destroy-wrapped": "deny",
  "state-rm": "deny", "drop-database": "deny", "delete-volumes": "deny",
  plan: "allow", "edit-config": "allow", "view-config": "allow",
};

function reportProblems(path, content, headings) {
  if (!content) return [`Add ${path}.`];
  const problems = [];
  if (/\b(?:TODO|TBD|replace-me)\b|<your[^>]*>/i.test(content)) {
    problems.push(`Replace the unfinished placeholders in ${path}.`);
  }
  const sections = content.split(/^##\s+/m).slice(1);
  for (const heading of headings) {
    const section = sections.find((text) => text.split(/\r?\n/, 1)[0].trim() === heading);
    const body = section?.slice(section.indexOf("\n") + 1).trim();
    if (!body || body.length < 40) {
      problems.push(`In ${path}, add "## ${heading}" with at least 40 characters of concrete evidence.`);
    }
  }
  return problems;
}

// Locally (`npm run checkpoint`) evidence comes from `make evidence`; the coach
// accepts only artifacts from the Actions run for this repository and commit.
function evidenceProblems(evidence, { local, repository, sha, runId, runAttempt }, source = "CI") {
  if (!evidence) return [`Wait for ${source} on this default-branch commit to publish its evidence artifact.`];
  if (evidence.schemaVersion !== 1) return [`${source} published evidence in an unknown format.`];
  if (local) return [];
  if (evidence.repository !== repository || evidence.sourceSha !== sha ||
      !Number.isSafeInteger(evidence.runId) || evidence.runId !== Number(runId) ||
      !Number.isSafeInteger(evidence.runAttempt) || evidence.runAttempt < 1 || evidence.runAttempt !== Number(runAttempt)) {
    return [`The evidence must come from ${source} for this repository, commit, run, and attempt.`];
  }
  return [];
}

function drillProblems(drill) {
  return drill?.outcome === "restored" && Number.isSafeInteger(drill.rowsExpected) && drill.rowsExpected > 0 &&
    drill.rowsRestored === drill.rowsExpected ? [] :
    ["The restore drill must restore every row of the independent backup."];
}

function replayProblems(replay) {
  const problems = [];
  if (replay?.outcome !== "blocked") {
    problems.push(`The incident replay must leave production intact; it was ${replay?.outcome ?? "not run"}.`);
  }
  if (replay?.newLaptopPlan?.add !== 0) {
    problems.push("A fresh clone must see production through remote state: the replay's new-laptop plan still wanted to create resources.");
  }
  return problems;
}

function agentProblems(agent) {
  if (agent?.outcome !== "guarded") {
    const detail = agent?.outcome === "leaky" ? `leaks: ${agent.leaks.join(", ")}` :
      agent?.outcome === "overblocking" ? `over-blocks: ${agent.overblocks.join(", ")}` : agent?.outcome ?? "not run";
    return [`The agent replay must deny every destructive call and allow safe ones (${detail}).`];
  }
  const results = new Map((agent.results ?? []).map((result) => [result.id, result]));
  return Object.entries(REQUIRED_AGENT_CASES)
    .filter(([id, expect]) => results.get(id)?.expect !== expect || results.get(id)?.pass !== true)
    .map(([id, expect]) => `Keep the incident's "${id}" call in tests/incident/agent-tool-calls.json, expecting ${expect}.`);
}

function releaseProblems(release, context) {
  if (!release?.run) {
    return ["Run the Release workflow on this default-branch commit, review its plan, and approve the production deployment."];
  }
  const approved = (release.approvals ?? []).some((review) => review.state === "approved" &&
    (review.environments ?? []).some((environment) => environment.name === "production"));
  if (!approved) {
    return ["The Release run had no human approval. Add yourself as a required reviewer of the production environment, then run Release again and approve it."];
  }
  const problems = evidenceProblems(release.evidence,
    { ...context, local: false, runId: release.run.id, runAttempt: release.run.run_attempt }, "the Release workflow");
  if (problems.length) return problems;
  const { release: applied, incidentReplay, agentReplay } = release.evidence;
  if (applied?.applied !== true || applied?.plan?.destroy !== 0) {
    problems.push("The Release run must apply an approved plan that deletes nothing.");
  }
  return [...problems, ...replayProblems(incidentReplay), ...agentProblems(agentReplay)];
}

function codeownersCovers(content, pattern) {
  return (content ?? "").split(/\r?\n/).some((line) => {
    const [path, ...owners] = line.replace(/#.*/, "").trim().split(/\s+/);
    return path && pattern.test(path) && owners.some((owner) => /^@[\w.-]+(\/[\w.-]+)?$|^[^@\s]+@[^@\s]+$/.test(owner));
  });
}

async function readAll(paths, readText) {
  let text = "";
  for (const path of paths) text += `${await readText(path) ?? ""}\n`;
  return text;
}

async function evaluateStep(step, context) {
  const { readText, listPaths, ciPassed, evidence } = context;
  const problems = [];
  const need = (condition, message) => { if (!condition) problems.push(message); };
  if (!Number.isInteger(step) || step < 1 || step > 6) throw new Error(`Unknown checkpoint: ${step}`);
  for (const [path, headings] of REPORTS[step]) {
    problems.push(...reportProblems(path, await readText(path), headings));
  }
  const checkRuntime = ![1, 3].includes(step) && !context.skipEvidence;
  const runtime = checkRuntime ? evidenceProblems(evidence, context) : [];
  problems.push(...runtime);
  const verified = checkRuntime && runtime.length === 0;

  if (step === 2 && verified) problems.push(...drillProblems(evidence.drill));

  if (step === 4) {
    const paths = await listPaths();
    const terraform = await readAll(paths.filter((path) => /^infrastructure\/lab\/[^/]+\.tf$/.test(path)), readText);
    need(/resource\s+"terraform_data"\s+"course_platform_db"/.test(terraform),
      "Keep the production database at terraform_data.course_platform_db in infrastructure/lab.");
    need(/lifecycle\s*\{[^}]*prevent_destroy\s*=\s*true/.test(terraform),
      "Protect the database with lifecycle { prevent_destroy = true }.");
    need(/delete_automated_backups\s*=\s*false/.test(terraform),
      "Keep automated backups when the database is deleted: set delete_automated_backups = false.");
    need(/backend\s+"pg"/.test(terraform),
      "Move Terraform state to the shared state store with a backend \"pg\" block.");
    const owners = await readAll(["CODEOWNERS", ".github/CODEOWNERS", "docs/CODEOWNERS"], readText);
    need(codeownersCovers(owners, /^\/?(infrastructure(\/|\/\*\*)?|\*\.tf)$/),
      "Add a CODEOWNERS rule that assigns an owner to infrastructure/.");
    need(codeownersCovers(owners, /^\/?\.github(\/|\/\*\*|\/hooks\/?|\/workflows\/?)?$/),
      "Add a CODEOWNERS rule that assigns an owner to .github/ (hooks and workflows).");
    if (verified) problems.push(...replayProblems(evidence.incidentReplay));
  }

  if (step === 5) {
    const paths = await listPaths();
    let hooked = false;
    for (const path of paths.filter((name) => /^\.github\/hooks\/[^/]+\.json$/.test(name))) {
      try {
        const config = JSON.parse(await readText(path) ?? "");
        hooked ||= config.version === 1 && Array.isArray(config.hooks?.preToolUse) && config.hooks.preToolUse.length > 0;
      } catch {
        problems.push(`${path}: fix the invalid JSON; Copilot ignores the whole file.`);
      }
    }
    need(hooked, "Add a preToolUse command hook in .github/hooks/*.json.");
    const instructions = await readAll(paths.filter((path) => /^\.github\/instructions\/[^/]+\.instructions\.md$/.test(path)), readText);
    need(/applyTo:\s*["']?[^\n]*infrastructure/.test(instructions),
      "Add path-specific instructions in .github/instructions/ with applyTo covering infrastructure/.");
    const agent = await readText(".github/agents/infra-operator.agent.md");
    need(agent?.includes("description:") && agent?.includes("tools:") && /approv/i.test(agent),
      "Create .github/agents/infra-operator.agent.md with a description, explicit tools, and human-approval boundaries.");
    if (verified) problems.push(...agentProblems(evidence.agentReplay));
  }

  if (step === 6) {
    const review = await readText(".github/workflows/guardrail-review.md");
    const lock = await readText(".github/workflows/guardrail-review.lock.yml");
    need(review?.includes("workflow_dispatch") && review?.includes("safe-outputs:") && review?.includes("contents: read"),
      "Keep the guardrail review manually dispatched, read-only, and bounded by safe outputs.");
    need(/^\s+max:\s*1\s*$/m.test(review ?? "") && /read-only:\s*true/.test(review ?? ""),
      "Keep the review's one-issue safe-output limit and read-only GitHub tools.");
    need(/checkout:\s*false/.test(review ?? "") && /bash:\s*false/.test(review ?? "") && /edit:\s*false/.test(review ?? ""),
      "Disable checkout, shell, and edit tools for the guardrail review.");
    need(lock?.includes("gh-aw") && lock?.includes("workflow_dispatch"), "Compile and commit guardrail-review.lock.yml.");
    if (verified) {
      need(evidence.enforced === true, "Turn the replay into a regression gate: set LAB_ENFORCE to \"true\" in .github/workflows/ci.yml.");
      problems.push(...drillProblems(evidence.drill), ...replayProblems(evidence.incidentReplay), ...agentProblems(evidence.agentReplay));
    }
    if (!context.local) problems.push(...releaseProblems(context.release, context));
  }

  if (!ciPassed) problems.push("Wait for a successful CI push run on this exact default-branch commit.");
  return { step, passed: problems.length === 0, problems };
}

module.exports = {
  evaluateStep, reportProblems, evidenceProblems, drillProblems, replayProblems, agentProblems,
  releaseProblems, codeownersCovers, REPORTS, REQUIRED_AGENT_CASES,
};
