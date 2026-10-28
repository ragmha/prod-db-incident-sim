## Step 3: Write a blameless postmortem and a guardrail plan

The engineer took responsibility for the incident, but blaming a person rarely prevents
the next one. A blameless postmortem asks which conditions let a plausible request turn
into a disaster, then plans a guardrail for each condition with a check that proves it
works.

This is where agents earn their place in the loop. An agent can gather the evidence and
draft the analysis quickly. A human decides what is true and what to build.

### Activity

1. Create a branch: `git switch -c lab/postmortem`.
2. Start `copilot` in the terminal (or open Copilot Chat) and ask it to use the
   `blameless-postmortem` skill:

   ```text
   Use the blameless-postmortem skill to draft evidence/03-postmortem.md from
   evidence/01-incident.md, evidence/02-recovery.md, .lab/new-laptop/*.txt, and
   .lab/evidence/*.json. Do not change any other file and do not run commands.
   ```

3. Review the draft critically. Check every claim against the replay output and the
   [incident account](https://alexeyondata.substack.com/p/how-i-dropped-our-production-database).
   Remove anything unsupported, and keep the lab's events separate from the real incident's.
4. Make sure the guardrail plan covers each layer, with an acceptance check you can run:

   | Layer | Question to answer | Built in |
   | --- | --- | --- |
   | State | How does a fresh clone see production? | Step 4 |
   | Configuration | What stops a routine destroy from deleting the database? | Step 4 |
   | Backups | Which backup survives the database's deletion? | Step 4 |
   | Ownership and review | Who must review infrastructure, hook, and workflow changes? | Step 4 |
   | Agent permissions | What stops an agent's destructive command before it runs? | Step 5 |
   | Release | Who approves a production change, and what fails if the incident returns? | Step 6 |

5. Complete `## Human approval` yourself: who reviewed the plan, what they changed, and
   whether they approved it. A reviewer can be you, a peer, or your facilitator.
6. Optionally, file each guardrail as an issue. In Steps 4 and 5 you can hand them to an
   agent, such as Copilot cloud agent if your plan includes it.
7. Make sure `evidence/03-postmortem.md` has the `##` headings `Summary`,
   `Contributing factors`, `Guardrail plan`, and `Human approval`.
8. Open a pull request, wait for **CI**, and merge.
