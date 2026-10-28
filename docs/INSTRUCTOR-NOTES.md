# Instructor notes

## Workshop overview

**Title:** Turn a production incident into guardrails
**Duration:** about 2.5 hours instructor-led, or 3 hours self-paced
**Audience:** platform engineers, DevOps engineers, SREs, and developers who use AI agents
with infrastructure as code
**Prerequisites:** a GitHub account with Copilot, Codespaces, and Actions; basic Git and
Terraform. No cloud account is needed: everything runs in containers in a Codespace.

## Suggested timeline

| Time | Activity | Step |
|---|---|---|
| 0:00–0:10 | The incident and the agentic SDLC loop | Discussion |
| 0:10–0:35 | Copy the template, start a Codespace, `make setup`, `make replay` | 1 |
| 0:35–0:50 | `make recover`, `make drill`, RTO and RPO | 2 |
| 0:50–1:10 | Agent-drafted, human-approved postmortem | 3 |
| 1:10–1:20 | Break | — |
| 1:20–1:45 | Agent-built infrastructure guardrails; replay is blocked | 4 |
| 1:45–2:10 | Hooks; `make agent-replay` until guarded; live test in Copilot CLI | 5 |
| 2:10–2:30 | Regression gate, approval-gated Release, agentic review | 6 |

Each step merges through a pull request. CI takes 2 to 3 minutes, so encourage learners to
start the next lesson's reading while CI runs.

## Discussion prompts

### After Step 1 (replay)

- At which moment could a person have stopped the chain? What would they have needed to know?
- Why did the plan look reasonable to the agent?

### After Step 2 (recovery)

- The lab restores in seconds; the real recovery took about 24 hours. What made the difference?
- When did your team last restore a production backup on purpose?

### After Step 3 (postmortem)

- Which parts of the agent's draft were wrong or unsupported? How did you find out?
- What makes a postmortem blameless without making it vague?

### After Step 4 (infrastructure guardrails)

- Which guardrail would have stopped the incident by itself? Which ones only reduce the damage?
- Why does `delete_automated_backups` need an apply before it protects anything?

### After Step 5 (agent hooks)

- Which bypasses did you find, and which ones are you accepting?
- Where is the line between a hook that protects and one that makes the agent useless?

### After Step 6 (release)

- Is a human approval meaningful if the reviewer doesn't read the plan?
- Which of your own incidents could become regression tests like this one?

## Common questions

**Is the lab realistic?** Terraform, its state, and the commands are real. The cloud is
modelled by `scripts/lab/control-plane.sh`, which creates and deletes a PostgreSQL database
the way a cloud API would: it carries out any valid request. The original incident was on
AWS; `docs/AWS-AZURE-MAPPING.md` and `infrastructure/azure` map each layer to Azure.

**Why doesn't the apply in the replay create duplicates?** The lab's database name is
unique, so the duplicate collides and the apply fails part-way, leaving a half-created
resource in the new state. That mirrors the engineer cancelling the apply after some
resources were created.

**What if learners can't run Copilot CLI?** Every agent activity also works in Copilot Chat
in VS Code. Repository hooks apply to Copilot CLI and Copilot cloud agent, so the live hook
test in Step 5 needs one of them; `make agent-replay` works for everyone.

**What if a learner's plan doesn't include environment protection?** Required reviewers on
environments are available for public repositories on every plan. Ask learners to keep
their copy public, which is the template's default.

## Setup checklist

- Confirm that learners can create Codespaces and run Actions in the account or
  organization they will use.
- Ask learners to copy the template rather than fork it, and to keep Issues and Actions on.
- Run the exercise once yourself, including a Release run, before the workshop.
