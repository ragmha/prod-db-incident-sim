import test from "node:test";
import assert from "node:assert/strict";
import { resolve } from "node:path";
import { compilerInvocation, requireCompilerVersion, runtimeRevision, workflowName } from "../scripts/compile-review.mjs";
import { compareWorkflowLocks } from "../scripts/check-review-lock.mjs";

const lock = `# gh-aw-metadata: {"compiler_version":"v0.86.2","frontmatter_hash":"abc"}
# gh-aw-manifest: {"actions":[{"repo":"example/action","sha":"123"}]}
name: Example
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  example:
    runs-on: ubuntu-24.04
    steps:
      - uses: example/action@123
      - run: |
          echo "hello"
`;

test("the compiler must report the exact pinned version before changing the lock", () => {
  assert.equal(workflowName, "guardrail-review");
  assert.doesNotThrow(() => requireCompilerVersion("gh aw version v0.86.2\n"));
  for (const output of ["gh aw version v0.88.7", "v0.86.2", "", "gh aw version v0.86.20"]) {
    assert.throws(() => requireCompilerVersion(output), /Expected gh-aw/);
  }
  assert.match(runtimeRevision, /^[a-f0-9]{40}$/);
});

test("explicit compiler paths bypass preinstalled extensions without shell evaluation", () => {
  assert.deepEqual(compilerInvocation(undefined), { command: "gh", prefix: ["aw"] });
  const binary = resolve("compiler-fixture");
  assert.deepEqual(compilerInvocation(binary), { command: binary, prefix: [] });
  assert.throws(() => compilerInvocation("compiler --unexpected-command"), /absolute path/);
});

test("lock comparison tolerates only non-executable comments and formatting", () => {
  const generated = lock.replace("uses: example/action@123", "uses: example/action@123 # 123");
  assert.doesNotThrow(() => compareWorkflowLocks(lock, generated.replace(/\n/g, "\r\n")));
});

test("lock comparison rejects permission, script, compiler, and dependency changes", () => {
  for (const generated of [
    lock.replace("contents: read", "contents: write"),
    lock.replace('echo "hello"', 'echo "changed"'),
    lock.replace("v0.86.2", "v0.88.7"),
    lock.replace('"sha":"123"', '"sha":"456"'),
    lock.replace('"frontmatter_hash":"abc"', '"frontmatter_hash":"different"'),
  ]) assert.throws(() => compareWorkflowLocks(lock, generated));
  assert.throws(() => compareWorkflowLocks(lock, lock.replace("# gh-aw-metadata:", "# absent:")), /missing/);
  assert.throws(() => compareWorkflowLocks(lock, `${lock}\nname: Duplicate\n`), /unique|repeated|duplicate/i);
});
