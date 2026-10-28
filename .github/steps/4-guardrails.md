## Step 4: Build the infrastructure guardrails

Now an agent writes the change and you stay in control of production. The agent edits
code; you review the diff, read the plan, and apply it.

Build these guardrails in `infrastructure/lab` and the repository root:

| Guardrail | Change | Real-world equivalent |
| --- | --- | --- |
| Shared state | Add `backend "pg" {}` to the `terraform` block. It stores state in the lab's state store, which `PG_CONN_STR` points to | An S3 or Azure Storage backend with locking |
| Deletion protection | Add `lifecycle { prevent_destroy = true }` to `terraform_data.course_platform_db` | RDS deletion protection, or an Azure `CanNotDelete` lock |
| Surviving backups | Set `delete_automated_backups = false` | Backups retained after deletion, plus copies in another account |
| Ownership | Add a `CODEOWNERS` file that assigns `/infrastructure/` and `/.github/` to you | Required review by the owning team |

### Activity

1. Create a branch: `git switch -c lab/guardrails`.
2. Ask an agent to make the change, without applying it. For example, in `copilot`:

   ```text
   Implement the state, configuration, and backup guardrails from
   evidence/03-postmortem.md in infrastructure/lab, keeping the resource address
   terraform_data.course_platform_db. Add a pg backend with no settings in the file,
   add prevent_destroy, and keep automated backups after deletion. Add a CODEOWNERS
   file that assigns /infrastructure/ and /.github/ to @<your-github-handle>.
   Run terraform fmt and terraform validate. Do not run apply, destroy, or any make
   target that changes production.
   ```

   You can also assign the guardrail issue from Step 3 to Copilot cloud agent and review
   its pull request instead.
3. Review the diff line by line. Then run `make plan-check`. It first moves your state
   into the state store, then saves a plan and fails if the plan deletes or replaces
   anything. Read the plan: it should change the database in place and destroy nothing.
4. Apply exactly that plan with `make apply`. A configuration change protects nothing
   until it is applied: Terraform reads `delete_automated_backups` from state when it
   deletes.
5. Run `make replay` again. This time the fresh clone should plan no changes, and the
   destroy should fail before it touches the database. Then run `make verify`.
6. Create `evidence/04-guardrails.md` with these `##` headings: `Agent work`,
   `Human review`, and `Replay result`. Describe what the agent proposed, what you
   changed or rejected, and the replay outcome.
7. Open a pull request, wait for **CI**, and merge.

The coach checks your configuration and CODEOWNERS file, and requires CI's replay of
your merged commit to leave production intact.

**Tip:** If CI's Terraform format check fails, run `terraform fmt -recursive infrastructure`.
If `make plan-check` reports that the database would be replaced, revise the change:
the plan guard is doing its job.
