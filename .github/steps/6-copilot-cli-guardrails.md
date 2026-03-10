## 🤖 Step 6: Copilot CLI Guardrails — Human-in-the-Loop

_The final and perhaps most important guardrail: ensuring AI agents can't execute destructive operations without human approval._

### 📖 The Core Problem

In the real incident, the AI coding agent:
- ✅ Was given **unrestricted terminal access**
- ✅ Could run **any command** including `terraform destroy`
- ✅ Could **modify files** (silently replaced the state file)
- ✅ Had **auto-approve** capability

The engineer's post-incident rule: _"All permissions are disabled. No automatic execution. No file writes."_

### 🤖 How Copilot CLI Is Different

GitHub Copilot CLI is designed with **human-in-the-loop** as a core principle:

| Feature | What It Does |
|---|---|
| **Permission prompts** | Every shell command shown to you BEFORE execution — you approve or reject |
| **Plan mode** (`/plan` or `Shift+Tab`) | Creates a reviewable plan before any action |
| **Directory scoping** (`/add-dir`, `/list-dirs`) | Controls which directories the agent can access |
| **Custom instructions** (`.github/copilot-instructions.md`) | Domain-specific rules the agent follows |
| **Session isolation** | Each session is independent — no state bleed |
| **`/diff`** | Review all file changes before committing |

### 🔑 Key Contrast

| Real Incident (Claude Code) | Copilot CLI |
|---|---|
| `terraform destroy` ran autonomously | Command shown, user must approve |
| State file replaced silently | File changes shown before writing |
| No plan review | Plan mode is a first-class feature |
| Auto-approve delegated to AI | No auto-approve — human decides |
| Unrestricted file system access | Directory scoping restricts access |
| No domain-specific rules | Custom instructions file |

### 🎯 What You'll Do

1. Create a Copilot CLI custom instructions file with safety rules
2. Fill in a comparison table of incident vs guardrail
3. Write a brief reflection

### 📋 Instructions

**1. Complete the Copilot CLI instructions template:**

```bash
cp infrastructure/guardrails/templates/copilot-instructions.md.template .github/copilot-instructions-learner.md
```

Open the file and fill in all TODO sections. Your instructions should cover:
- 🚫 Never execute `terraform apply` or `terraform destroy` directly
- 📋 Always use plan mode for infrastructure changes
- ⚠️ Explain blast radius before destructive operations
- 🔒 Never modify Terraform state files
- 🔍 Always verify target environment (dev/staging/production)

**2. Fill in the comparison table:**

In the same file, complete the table mapping each incident failure to how Copilot CLI handles it.

**3. Write a reflection:**

Create `evidence/step-6-reflection.md`:
```markdown
# Copilot CLI Guardrails Reflection

## How Copilot CLI Would Have Prevented Each Incident Step

1. Missing state file → ...
2. AI ran terraform apply → ...
3. AI replaced state file → ...
4. AI ran terraform destroy → ...
5. No human reviewed the plan → ...

## Custom Instructions I Would Add for MY Azure Infrastructure

- ...
- ...
- ...

## Key Takeaway

(Your one-sentence takeaway about AI agents and infrastructure safety)
```

### 💡 Stuck?

Check `solutions/step-6-copilot/` for a reference implementation.

### ✅ Complete This Step

Push your completed files:

```bash
git add .github/copilot-instructions-learner.md evidence/step-6-reflection.md
git commit -m "step 6: Copilot CLI guardrails and reflection completed"
git push
```

### 🎉 Congratulations!

If you've completed all 6 steps, you've:

- 🏗️ Built a production environment and understood what's at stake
- 💥 Experienced the exact failure chain from a real incident
- 🔧 Practiced database recovery from backup
- 🔒 Implemented Azure guardrails (resource locks, immutable backups, remote state)
- 🛡️ Implemented GitHub guardrails (CODEOWNERS, Actions workflows, environments)
- 🤖 Configured AI agent guardrails (custom instructions, plan mode)

**The key lesson:** AI coding agents are incredibly powerful, but infrastructure operations require **defense-in-depth** — multiple layers of protection so that no single failure can destroy production.

> _"I over-relied on the AI agent to run Terraform commands. That removed the last safety layer."_ — From the original article
