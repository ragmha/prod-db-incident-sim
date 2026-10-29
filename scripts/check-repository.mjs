import { readFile, access } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { parseDocument } from "yaml";
import { listPaths } from "./checkpoint.mjs";
import exercise from "../.github/scripts/exercise.cjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const failures = [];
const files = await listPaths();
const need = (condition, message) => { if (!condition) failures.push(message); };
const text = (path) => readFile(resolve(root, path), "utf8");

for (const path of [
  "README.md", "LICENSE", "Makefile", "docker-compose.yml", "database/seed-data.sql",
  "infrastructure/lab/main.tf", "tests/incident/agent-tool-calls.json",
  ".devcontainer/devcontainer.json", ".github/workflows/ci.yml", ".github/workflows/exercise.yml",
  ".github/workflows/release.yml", ".github/workflows/guardrail-review.md",
]) need(files.includes(path), `Missing required repository surface: ${path}`);

// The starter must stay vulnerable, or Step 1 has nothing to replay. Learner
// copies change these files on purpose, so check them only in the template.
const checkStarter = process.argv.includes("--starter") || process.env.GITHUB_REPOSITORY === "ragmha/prod-db-incident-sim";
if (checkStarter) {
  const starter = await text("infrastructure/lab/main.tf");
  need(!/prevent_destroy|backend\s+"/.test(starter) && /delete_automated_backups\s*=\s*true/.test(starter),
    "infrastructure/lab/main.tf must remain the vulnerable starter configuration.");
  for (const path of ["CODEOWNERS", ".github/CODEOWNERS"]) need(!files.includes(path), `Learners create ${path} in Step 4.`);
  need(!files.some((path) => path.startsWith(".github/hooks/") || path.startsWith(".github/instructions/")),
    "Learners create .github/hooks and .github/instructions in Step 5.");
  need(!files.some((path) => path.startsWith("evidence/") && path !== "evidence/README.md"),
    "Learner reports must not ship in the starter.");
  need((await text(".github/workflows/ci.yml")).includes('LAB_ENFORCE: "false"'),
    "The starter's CI must not enforce the regression gate; learners turn it on in Step 6.");
  const lockPath = ".github/workflows/guardrail-review.lock.yml";
  need(!execFileSync("git", ["ls-files", "--", lockPath], { cwd: root, encoding: "utf8" }).trim(),
    `Don't commit ${lockPath} in the template; learners compile and commit it in Step 6.`);
}

for (const path of files.filter((path) => /\.(?:ya?ml)$/.test(path))) {
  const document = parseDocument(await text(path), { uniqueKeys: true });
  for (const error of document.errors) failures.push(`${path}: ${error.message}`);
  if (!path.startsWith(".github/workflows/")) continue;
  const workflow = document.toJS();
  need(workflow?.name && workflow?.on && workflow?.jobs, `${path}: workflow requires name, on, and jobs.`);
  need(!workflow?.on?.pull_request_target, `${path}: untrusted PRs must not run with elevated privileges.`);
  for (const [jobId, job] of Object.entries(workflow?.jobs ?? {})) {
    for (const step of job.steps ?? []) {
      if (step.uses && !step.uses.startsWith("./") && !step.uses.startsWith("docker://")) {
        need(/@[a-f0-9]{40}$/.test(step.uses), `${path}/${jobId}: pin action ${step.uses} to a full commit SHA.`);
      }
    }
  }
}

const devcontainer = JSON.parse(await text(".devcontainer/devcontainer.json"));
need(devcontainer.features?.["ghcr.io/devcontainers/features/docker-in-docker:2"], "The Codespace needs Docker for the lab.");
need(devcontainer.features?.["ghcr.io/devcontainers/features/terraform:1"]?.version === "1.17.0",
  "The Codespace must pin the Terraform version that CI uses.");
need(devcontainer.otherPortsAttributes?.onAutoForward === "ignore", "Do not automatically expose the lab's database ports.");

const readme = await text("README.md");
need(readme.includes("template_owner=ragmha&template_name=prod-db-incident-sim"),
  "Copy Exercise must point to the actual template repository.");
need(!readme.includes("codespaces.new/ragmha/prod-db-incident-sim"),
  "Do not send learners into the author's Codespace instead of their own copy.");
for (const lesson of exercise.LESSONS.filter(Boolean)) {
  need(files.includes(`.github/steps/${lesson}`), `Missing lesson .github/steps/${lesson}.`);
}

for (const path of files.filter((file) => file.endsWith(".md"))) {
  for (const match of (await text(path)).matchAll(/\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)) {
    const target = match[1].split("#")[0];
    if (!target || /^(?:[a-z]+:|#|\/|\{\{)/i.test(target) || target.startsWith("../../")) continue;
    try {
      await access(resolve(root, dirname(path), decodeURIComponent(target)));
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      failures.push(`${path}: broken local link ${target}`);
    }
  }
}

if (failures.length) {
  console.error(failures.map((failure) => `- ${failure}`).join("\n"));
  process.exitCode = 1;
} else {
  console.log(`Repository surfaces, ${checkStarter ? "starter state, " : ""}YAML, action pins, Codespace, and local links are consistent.`);
}
