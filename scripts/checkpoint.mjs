import { existsSync, readFileSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import checkpoints from "../.github/scripts/checkpoints.cjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const localEvidence = resolve(root, ".lab", "evidence", "lab-evidence.json");

export async function readText(path) {
  try {
    return await readFile(resolve(root, path), "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return undefined;
    throw error;
  }
}

export async function listPaths(directory = root) {
  const result = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    if ([".git", ".lab", ".terraform", "node_modules"].includes(item.name)) continue;
    const path = resolve(directory, item.name);
    if (item.isDirectory()) result.push(...await listPaths(path));
    else if (item.isFile()) result.push(relative(root, path).split(sep).join("/"));
  }
  return result;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const step = Number(process.argv[2]);
  if (!Number.isInteger(step) || step < 1 || step > 6) throw new Error("Usage: npm run checkpoint -- <1-6>");
  const evidence = existsSync(localEvidence) ? JSON.parse(readFileSync(localEvidence, "utf8")) : undefined;
  const result = await checkpoints.evaluateStep(step, {
    readText, listPaths, ciPassed: true, evidence, local: true, skipEvidence: !evidence,
  });
  console.log(`Checkpoint ${step}: ${result.passed ? "ready" : "not ready"}`);
  for (const problem of result.problems) console.error(`  - ${problem}`);
  if (![1, 3].includes(step)) {
    console.log(evidence ? "Runtime results came from your last make evidence run." :
      "Runtime results were not checked. Run make evidence to include them.");
    console.log("After you merge, the coach repeats these checks against CI's run for that commit.");
  }
  if (step === 6) console.log("The coach also checks your approved Release run, which only Actions can show.");
  process.exitCode = result.passed ? 0 : 1;
}
