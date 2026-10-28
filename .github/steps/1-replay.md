## Step 1: Replay the incident

On the evening of 26 February 2026, an engineer asked an AI coding agent to deploy
website changes with Terraform from a new laptop. About an hour later, the production
infrastructure of a course platform was gone: its database, network, containers, load
balancers, and bastion host, and with them two and a half years of homework submissions.
The automated database snapshots were deleted too. Getting the data back took about
24 hours and a paid support upgrade. The engineer published
[a candid account](https://alexeyondata.substack.com/p/how-i-dropped-our-production-database)
of what happened.

In this step you replay that failure chain with real Terraform commands, against a
disposable production that runs in containers in your Codespace.

| What happened | In the lab |
| --- | --- |
| The Terraform state stayed on the old laptop | `make replay` copies `infrastructure/lab` to `.lab/new-laptop` without its state |
| `terraform plan` proposed creating production again | The replay runs the same plan |
| An auto-approved apply began creating duplicates | The apply collides with the existing database and fails part-way |
| The agent unpacked the old Terraform archive over the new state | The replay copies production's state into the new laptop |
| `terraform destroy -auto-approve` deleted production and its snapshots | The replay runs it |

### Activity

1. [Create a Codespace in **your copy**](https://codespaces.new/{{repository}}) and wait for its setup to finish.
2. Create a branch: `git switch -c lab/incident`.
3. Run `make doctor`, then `make setup`. Terraform provisions the database, the course
   data loads, and two backups are taken: an automated backup on the database server and
   an independent export in `.lab/offsite`.
4. Run `make verify` and `make snapshots`, and note the row counts and the automated backup.
5. Run `make replay`. It pauses before each command, so read what happened before you
   continue. **It deletes the production database.**
6. Run `make verify` and `make snapshots` again.
7. Ask Copilot to explain the replay, using the read-only incident analyst provided in
   this repository. In the terminal, start `copilot`, select **Incident analyst** with
   `/agent`, and ask:

   ```text
   Read .lab/new-laptop/plan.txt, apply.txt, and destroy.txt, and
   .lab/evidence/incident-replay.json. Explain what Terraform believed at each
   step and why, what the destroy deleted, and why no automated backup is left.
   Cite the files you used, and say which points are inference.
   ```

   You can also pick the agent in Copilot Chat in VS Code. It can read and search, but it
   cannot edit files or run commands.
8. Create `evidence/01-incident.md` with these `##` headings: `Timeline`,
   `What Terraform believed`, `Blast radius`, and `Where it could have stopped`. Write at
   least 40 characters of concrete observations under each: commands, outputs, and row
   counts. No placeholders.
9. Open a pull request, read its diff, wait for **CI**, and merge.

CI rebuilds production on its runner and replays the incident on every commit. The
result goes to the `lab-evidence` artifact, which the coach reads. Your Codespace's
production stays deleted until Step 2.

The coach checks the default branch after CI. Comment `/check` here to retry.
