#!/usr/bin/env node
// Reads `terraform show -json <planfile>` on stdin.
//
//   plan-guard.mjs            fail when the plan deletes or replaces anything
//   plan-guard.mjs --summary  print "<add> <change> <destroy>"
//   plan-guard.mjs --changes  print the planned changes as compact JSON, used
//                             to confirm that a release applies what was approved
//
// Production changes in this lab must never delete or replace the database.
// A deliberate decommission belongs in a separate, explicitly approved process.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

export function summarizePlan(plan) {
  const summary = { add: 0, change: 0, destroy: 0, deletions: [], changes: [] };
  for (const resource of plan?.resource_changes ?? []) {
    const actions = resource.change?.actions ?? [];
    if (actions.includes("create")) summary.add++;
    if (actions.includes("update")) summary.change++;
    if (actions.includes("delete")) {
      summary.destroy++;
      summary.deletions.push(resource.address);
    }
    if (!actions.every((action) => action === "no-op" || action === "read")) {
      summary.changes.push(`${resource.address}:${actions.join("+")}`);
    }
  }
  summary.changes.sort();
  return summary;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const summary = summarizePlan(JSON.parse(readFileSync(0, "utf8")));
  if (process.argv.includes("--summary")) {
    console.log(`${summary.add} ${summary.change} ${summary.destroy}`);
  } else if (process.argv.includes("--changes")) {
    console.log(JSON.stringify(summary.changes));
  } else if (summary.deletions.length) {
    console.error(`Plan guard: this plan deletes or replaces ${summary.deletions.join(", ")}.`);
    console.error("Production must not be deleted through a routine change. Revise the change, or use a separately approved decommission.");
    process.exitCode = 1;
  } else {
    console.log(`Plan guard: ${summary.add} to add, ${summary.change} to change, nothing deleted or replaced.`);
  }
}
