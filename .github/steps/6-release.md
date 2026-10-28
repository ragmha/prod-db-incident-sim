## Step 6: Release through a gate

Two things close the loop. First, the incident becomes a regression test: CI fails
whenever the replay would lose production. Second, production changes only through a
pipeline that a human approves after reading the plan.

The provided **Release** workflow rebuilds production with the starter's configuration,
plans your configuration against it, and publishes the plan. Its apply job uses the
`production` environment, so it waits for a required reviewer before it applies the
approved plan. Afterwards it replays the incident against the released production.

A bounded agentic review adds a second opinion that cannot change anything.

### Activity

1. Create a branch: `git switch -c lab/release`.
2. **Regression gate.** In `.github/workflows/ci.yml`, set `LAB_ENFORCE` to `"true"`.
   To see the gate work, push a throwaway branch that removes `prevent_destroy`, open a
   draft pull request, watch CI fail, then close it.
3. **Agentic review.** Tailor `.github/workflows/guardrail-review.md` to your guardrails,
   then compile it with the pinned compiler:

   ```bash
   npm run compile:review
   ```

   Commit the Markdown and the generated `.lock.yml`. Don't edit the lock file by hand.
   Running the review live is optional and needs a separate token; see
   [the agentic workflow guide](https://github.com/{{repository}}/blob/{{branch}}/docs/agentic-workflows.md).
   If you don't run it, label your report **manual review; no live agent run**.
4. Open a pull request, wait for **CI**, and merge.
5. **Approval gate.** In **Settings → Environments**, create `production`, add yourself
   under **Required reviewers**, and save. (Public repositories support required reviewers
   on every plan; private repositories need a plan that includes them.)
6. **Release.** In **Actions → Release**, run the workflow on your default branch. Read
   the **Plan for review** summary of the plan job, then use **Review deployments** to
   approve `production`. The apply job applies only the approved plan and fails if
   anything differs.
7. Create `evidence/06-release.md` with these `##` headings: `Regression gate`, `Release`,
   `Agentic review`, and `Human decision`. Link your Release run, summarize its plan, and
   record what you approved and why.
8. Open a pull request, wait for **CI**, and merge. Then **run Release again** for that
   merged commit and approve it. Every change on the default branch ships through the
   gate, including this one.

The coach checks CI's enforced gate, your compiled review workflow, and a successful,
human-approved Release run for the current commit whose post-release replay leaves
production intact.
