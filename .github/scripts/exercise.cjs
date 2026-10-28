const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execFileSync } = require("node:child_process");
const { evaluateStep } = require("./checkpoints.cjs");

const STATE = /<!-- incident-exercise:(\{[^\n]+\}) -->/;
const FEEDBACK = "<!-- incident-exercise-feedback -->";
const TITLE = "Exercise: Turn a production incident into guardrails";
const CANONICAL = "ragmha/prod-db-incident-sim";
const WORKFLOWS = [".github/workflows/ci.yml", ".github/workflows/release.yml"];
const LESSONS = [
  "", "1-replay.md", "2-recover.md", "3-postmortem.md",
  "4-guardrails.md", "5-agent-hooks.md", "6-release.md", "7-finish.md",
];
const FINISHED = LESSONS.length - 1;

function parseState(body) {
  const value = body?.match(STATE)?.[1];
  if (!value) return undefined;
  const state = JSON.parse(value);
  if (state.schema !== 1 || !Number.isInteger(state.step) || state.step < 1 || state.step > FINISHED) {
    throw new Error("The exercise issue has invalid state. Restore its original state marker before retrying.");
  }
  return state;
}

function relevantCompletion(run, repository, branch, sha) {
  return run?.conclusion === "success" && run.head_repository?.full_name === repository &&
    run.head_branch === branch && run.head_sha === sha && WORKFLOWS.includes(run.path);
}

function stateBody(step, repository, sha) {
  return [
    "# Turn a production incident into guardrails",
    `<!-- incident-exercise:${JSON.stringify({ schema: 1, step, sha })} -->`,
    step === FINISHED ? "**Exercise complete: the incident replays without losing production.**" :
      `**Current checkpoint: ${step} of ${FINISHED - 1}.** Follow the lesson comments below.`,
    "Work on a branch in your Codespace, open a pull request, wait for CI, and merge your reviewed changes.",
    "The coach checks the default branch after CI. A repository writer can comment `/check` to retry.",
    "Everything runs in local containers. Nothing in this exercise creates cloud resources.",
    `[Actions](https://github.com/${repository}/actions) | [Curriculum](https://github.com/${repository}/tree/HEAD/.github/steps)`,
  ].join("\n\n");
}

async function exercise({ github, context, core }) {
  const { owner, repo } = context.repo;
  const repository = `${owner}/${repo}`;
  const metadata = (await github.rest.repos.get({ owner, repo })).data;
  const preview = context.eventName === "workflow_dispatch" && String(context.payload.inputs?.preview) === "true";
  if ((metadata.is_template || repository === CANONICAL) && !preview) {
    core.notice("Template source: the exercise starts in learner copies. Dispatch with preview=true to preview the coach here.");
    return;
  }
  if (!metadata.has_issues) throw new Error("Enable Issues in repository settings so the exercise coach can post lessons.");
  const branch = metadata.default_branch;
  const sha = (await github.rest.repos.getBranch({ owner, repo, branch })).data.commit.sha;
  if (context.eventName === "push" && context.payload.ref !== `refs/heads/${branch}`) return;
  if (context.eventName === "workflow_run" &&
      !relevantCompletion(context.payload.workflow_run, repository, branch, sha)) {
    core.notice("Ignoring a failed, stale, foreign, or unrelated workflow completion.");
    return;
  }
  if (context.eventName === "issue_comment") {
    if (context.payload.issue.pull_request || context.payload.comment.body.trim() !== "/check") return;
    const permission = (await github.rest.repos.getCollaboratorPermissionLevel({
      owner, repo, username: context.payload.comment.user.login,
    })).data.permission;
    if (!["admin", "maintain", "write"].includes(permission)) {
      core.notice("Only a repository writer may request an exercise check.");
      return;
    }
  }

  const issues = await github.paginate(github.rest.issues.listForRepo, { owner, repo, state: "all", per_page: 100 });
  let issue = issues.find((item) => !item.pull_request && item.user?.login === "github-actions[bot]" && STATE.test(item.body ?? ""));
  const lesson = (step) => fs.readFileSync(path.join(__dirname, "..", "steps", LESSONS[step]), "utf8")
    .replaceAll("{{repository}}", repository).replaceAll("{{branch}}", branch);
  if (!issue) {
    issue = (await github.rest.issues.create({ owner, repo, title: TITLE, body: stateBody(1, repository, sha) })).data;
  }
  if (context.eventName === "issue_comment" && context.payload.issue.number !== issue.number) return;
  let state = parseState(issue.body);
  if (!state) throw new Error("Exercise issue state is missing.");
  if (state.step === FINISHED) {
    core.notice("This exercise is already complete.");
    return;
  }
  const comments = await github.paginate(github.rest.issues.listComments, {
    owner, repo, issue_number: issue.number, per_page: 100,
  });
  async function postLesson(step) {
    const marker = `<!-- incident-lesson:${step} -->`;
    if (!comments.some((comment) => comment.user?.login === "github-actions[bot]" && comment.body.includes(marker))) {
      const comment = (await github.rest.issues.createComment({
        owner, repo, issue_number: issue.number, body: `${marker}\n${lesson(step)}`,
      })).data;
      comments.push(comment);
    }
  }
  await postLesson(state.step);

  const cache = new Map();
  async function readText(filePath) {
    if (!cache.has(filePath)) {
      try {
        const file = (await github.rest.repos.getContent({ owner, repo, path: filePath, ref: sha })).data;
        if (Array.isArray(file) || file.type !== "file" || file.encoding !== "base64" || file.size > 1_000_000) {
          throw new Error(`Expected a small, ordinary text file: ${filePath}`);
        }
        cache.set(filePath, Buffer.from(file.content, "base64").toString("utf8"));
      } catch (error) {
        if (error.status !== 404) throw error;
        cache.set(filePath, undefined);
      }
    }
    return cache.get(filePath);
  }
  let tree;
  async function listPaths() {
    if (!tree) {
      const response = (await github.rest.git.getTree({ owner, repo, tree_sha: sha, recursive: "1" })).data;
      if (response.truncated) throw new Error("The repository tree is too large for the exercise coach.");
      tree = response.tree.filter((entry) => entry.type === "blob").map((entry) => entry.path);
    }
    return tree;
  }
  async function latestRun(workflow, event) {
    const runs = (await github.rest.actions.listWorkflowRuns({
      owner, repo, workflow_id: workflow, head_sha: sha, branch, event, per_page: 20,
    })).data.workflow_runs;
    return runs.find((run) => run.head_sha === sha && run.head_repository?.full_name === repository && run.head_branch === branch);
  }
  async function readEvidence(run, name) {
    const artifacts = await github.paginate(github.rest.actions.listWorkflowRunArtifacts, {
      owner, repo, run_id: run.id, per_page: 100,
    });
    const artifact = artifacts.find((item) => item.name === name && !item.expired);
    if (!artifact) return undefined;
    if (artifact.size_in_bytes > 2_000_000) throw new Error(`Unexpectedly large ${name} artifact.`);
    const response = await github.rest.actions.downloadArtifact({ owner, repo, artifact_id: artifact.id, archive_format: "zip" });
    const directory = fs.mkdtempSync(path.join(process.env.RUNNER_TEMP || os.tmpdir(), "exercise-evidence-"));
    const archive = path.join(directory, "evidence.zip");
    try {
      fs.writeFileSync(archive, Buffer.from(response.data));
      // Read one bounded data member without extracting files or executing artifact content.
      return JSON.parse(execFileSync("unzip", ["-p", archive, "lab-evidence.json"], { encoding: "utf8", timeout: 10_000, maxBuffer: 1_048_576 }));
    } finally {
      if (fs.existsSync(archive)) fs.unlinkSync(archive);
      fs.rmdirSync(directory);
    }
  }
  async function releaseInfo() {
    const run = await latestRun("release.yml", "workflow_dispatch");
    if (run?.conclusion !== "success") return {};
    const approvals = (await github.rest.actions.getReviewsForRun({ owner, repo, run_id: run.id })).data;
    return { run, approvals, evidence: await readEvidence(run, "release-evidence") };
  }

  const ci = await latestRun("ci.yml", "push");
  const ciPassed = ci?.conclusion === "success";
  const evidence = ciPassed ? await readEvidence(ci, "lab-evidence") : undefined;
  let release;

  while (state.step < FINISHED) {
    if (state.step === 6 && ciPassed && !release) release = await releaseInfo();
    const result = await evaluateStep(state.step, {
      readText, listPaths, ciPassed, evidence, release, repository, sha, runId: ci?.id, runAttempt: ci?.run_attempt,
    });
    if (!result.passed) {
      const body = `${FEEDBACK}\n### Checkpoint ${state.step}: not ready yet\n\n${result.problems.map((problem) => `- ${problem}`).join("\n")}\n\nChecked commit \`${sha.slice(0, 12)}\`. Review the current lesson, then merge your fixes or comment \`/check\`.`;
      const feedback = comments.find((comment) => comment.user?.login === "github-actions[bot]" && comment.body.includes(FEEDBACK));
      if (feedback) {
        if (feedback.body !== body) await github.rest.issues.updateComment({ owner, repo, comment_id: feedback.id, body });
      } else {
        await github.rest.issues.createComment({ owner, repo, issue_number: issue.number, body });
      }
      core.notice(`Checkpoint ${state.step} needs learner work.`);
      return;
    }
    const currentSha = (await github.rest.repos.getBranch({ owner, repo, branch })).data.commit.sha;
    if (currentSha !== sha) {
      core.notice("The default branch moved during checking; wait for CI on the new commit.");
      return;
    }
    state = { ...state, step: state.step + 1 };
    await github.rest.issues.update({
      owner, repo, issue_number: issue.number, body: stateBody(state.step, repository, sha),
      ...(state.step === FINISHED ? { state: "closed", state_reason: "completed" } : {}),
    });
    await postLesson(state.step);
  }
  const feedback = comments.find((comment) => comment.user?.login === "github-actions[bot]" && comment.body.includes(FEEDBACK));
  if (feedback) {
    await github.rest.issues.updateComment({
      owner, repo, comment_id: feedback.id,
      body: `${FEEDBACK}\nAll six checkpoints passed for \`${sha.slice(0, 12)}\`. Release run ${release.run.id} was approved by a human, applied a plan that deleted nothing, and replayed the incident without losing production.`,
    });
  }
}

module.exports = exercise;
module.exports.parseState = parseState;
module.exports.relevantCompletion = relevantCompletion;
module.exports.stateBody = stateBody;
module.exports.LESSONS = LESSONS;
