# Maintaining this exercise

## Design

The exercise reuses the coach pattern from
[modernize-app-with-copilot](https://github.com/ragmha/modernize-app-with-copilot): one
issue per learner copy, lessons posted as comments, and checkpoints checked by a small
Node.js coach against the trusted default branch. It replaced the earlier
exercise-toolkit workflows, which enabled and disabled one workflow per step and passed a
step whenever an evidence file existed.

| Concern | Where it lives |
| --- | --- |
| Lessons | `.github/steps/*.md` |
| Coach | `.github/scripts/exercise.cjs` (issue state, artifacts) and `checkpoints.cjs` (rules) |
| Lab | `docker-compose.yml`, `infrastructure/lab`, `scripts/lab`, `Makefile` |
| Agent replay | `scripts/replay-agent.mjs` and `tests/incident/agent-tool-calls.json` |
| Release | `.github/workflows/release.yml` and `scripts/lab/release.sh` |
| Agentic review | `.github/workflows/guardrail-review.md`; learners compile and commit its lock in Step 6 |

## Evidence the coach trusts

Reports in `evidence/` are checked for structure only; humans judge their substance.
Runtime claims come from artifacts the coach downloads itself:

- **CI** (`ci.yml`, push to the default branch) uploads `lab-evidence`: the restore drill,
  the incident replay, and the agent replay, plus whether the regression gate is enforced.
- **Release** (`release.yml`, `workflow_dispatch`) uploads `release-evidence` after its
  apply job. The coach also reads the run's approval history and requires an approved
  review for the `production` environment.

Both artifacts carry the repository, commit, run ID, and attempt, and the coach rejects
any mismatch. It reads one bounded JSON member from each zip without extracting or
executing anything. Its job has `issues: write` and `actions: read` only, checks out only
the default branch, and accepts `/check` only from repository writers.

## Template behavior

Keep the **Template repository** setting on, and keep the README's copy link pointing at
`template_owner=ragmha&template_name=prod-db-incident-sim`. The coach does nothing in a
template repository or in this canonical repository; dispatch **Exercise coach** with
`preview=true` to preview lessons here.

The starter must stay vulnerable: no backend, no `prevent_destroy`,
`delete_automated_backups = true`, no CODEOWNERS, hooks, or reports, and
`LAB_ENFORCE: "false"` in CI. It also ships the review workflow's source without its
compiled lock: compiling is part of Step 6, and generated lock files contain placeholders
such as `${MCP_GATEWAY_API_KEY}` that strict local secret scanners flag. `npm run check`
enforces all of this in the canonical repository.

The Release workflow rebuilds production from the first commit that added
`infrastructure/lab/main.tf`. In learner copies, that's the template's initial commit.

## Validation

```bash
npm ci --ignore-scripts
npm run verify          # unit tests and repository checks
make evidence           # full lab: drill, incident replay, agent replay
npm run compile:review  # needs gh-aw v0.86.2; don't commit the generated lock here
```

Before releasing a change, replay a learner copy end to end: break the starter with the
replay, add the Step 4 and Step 5 guardrails, confirm that `make evidence` with
`LAB_ENFORCE=true` passes, and run Release with an approval.

Keep action references at full commit SHAs, Terraform at the version pinned in CI and the
Codespace, and the gh-aw compiler at v0.86.2. Generate review locks only with
`npm run compile:review`; never edit them by hand.

## Known limits

- The control plane models a cloud API with a local PostgreSQL server. It shows state and
  lifecycle behavior faithfully, not cloud-specific APIs.
- The agent replay runs hooks the way Copilot CLI runs command hooks. It can't prove how a
  model would behave, and it doesn't cover HTTP hooks or VS Code agent hooks.
- Live agentic inference is optional and separately credentialed.
- The `infrastructure/azure` files are reference material and aren't applied by anything.
