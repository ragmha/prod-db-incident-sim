# 📖 Companion Guide: Preventing Production Database Disasters

> _"A backup you haven't tested is just a hope."_

---

## Introduction

On a Thursday night in February 2024, an engineer sat down to do some routine infrastructure
work. Twenty-four hours later, a production database holding **1.9 million rows** and
**2.5 years of irreplaceable student data** was gone — wiped out by a single command.

This guide is based on [a real incident documented by Alexey Grigorev](https://alexeyondata.substack.com/p/how-i-dropped-our-production-database),
who openly shared the painful story of how an AI coding agent (Claude Code), a missing
Terraform state file, and a series of compounding failures led to the destruction of a
production PostgreSQL database on AWS RDS.

**What makes this incident so instructive** isn't that someone ran `terraform destroy`.
It's that _every single safeguard that should have prevented catastrophe was either missing
or misconfigured_. The incident is a textbook case of how small, individually reasonable
decisions — storing state locally, co-locating unrelated infrastructure, granting an AI agent
unrestricted access — can chain together into a disaster.

This companion guide covers:

- **What happened** — the full timeline and root cause chain
- **Why it happened** — the five failures that compounded into catastrophe
- **How to prevent it** — defense-in-depth using Azure, GitHub, and Copilot CLI guardrails

Whether you're completing the hands-on exercise or reading this standalone, the lessons
here apply to anyone managing production infrastructure with Terraform, AI coding agents,
or both.

---

## The Incident — What Happened

### Timeline

| Time | Event |
|------|-------|
| **Thursday, ~10 PM** | Engineer starts working on infrastructure from a new laptop |
| **Thursday, ~10:15 PM** | Terraform can't find local state file — plans to _create_ all resources |
| **Thursday, ~10:30 PM** | AI agent runs `terraform apply`, creating duplicate infrastructure |
| **Thursday, ~10:45 PM** | AI agent attempts cleanup by unpacking an old state archive |
| **Thursday, ~11:00 PM** | AI agent runs `terraform destroy` — production database is deleted |
| **Thursday, ~11:05 PM** | Engineer discovers all tables are gone. Automated RDS snapshots are _also_ gone. |
| **Friday, all day** | Emergency recovery with AWS Business Support ($100/month saved the day) |
| **Friday, ~10 PM** | Database restored from a manual backup. 24 hours of downtime. |

### The Root Cause Chain

This wasn't a single mistake. It was a **chain of five failures**, each one making the next
one possible:

```
┌─────────────────────────────────────────────────────────────────┐
│                    THE FAILURE CHAIN                             │
│                                                                 │
│  ① Local State File     "New laptop, who dis?"                  │
│       ↓                                                         │
│  ② Shared Infrastructure  App + DB in same Terraform project    │
│       ↓                                                         │
│  ③ AI Agent Autonomy     Unrestricted terminal access           │
│       ↓                                                         │
│  ④ No Deletion Protection  deletion_protection = false          │
│       ↓                                                         │
│  ⑤ Coupled Backups       RDS snapshots deleted with instance    │
│       ↓                                                         │
│  💥 PRODUCTION DATABASE DESTROYED                                │
└─────────────────────────────────────────────────────────────────┘
```

### The Five Failures, Explained

#### Failure 1: Local Terraform State

Terraform tracks what it manages through a **state file** (`terraform.tfstate`). When the
engineer switched to a new laptop, this file didn't come along. Without it, Terraform
believed _nothing existed_ — it planned to create 17 brand-new resources, oblivious to
the production infrastructure already running.

**The fix:** Store state in a remote backend. In your Azure environment, use Azure Blob
Storage with built-in lease locking — no separate lock table needed. The state is always
accessible from any machine and protected by locking.

#### Failure 2: Shared Infrastructure

The application infrastructure (ECS, ALB, networking) and the database lived in the
**same Terraform project**. This meant a single `terraform destroy` could wipe out
everything — not just the app containers that were being modified, but the database
holding 2.5 years of student data.

**The fix:** Separate your infrastructure into independent projects with isolated blast
radii. The database should be in its own Terraform workspace, managed by a different
team or process.

#### Failure 3: Unrestricted AI Agent Access

The AI coding agent (Claude Code) had full terminal access. It could read files, write
files, and execute _any_ command — including `terraform destroy` — without human review.
The agent was trying to be helpful by cleaning up the duplicate resources it had created,
but it had no guardrails preventing destructive operations.

**The fix:** Use AI agents that require human approval before executing commands. GitHub
Copilot CLI, for example, shows every command before execution and waits for explicit
approval.

#### Failure 4: No Deletion Protection

AWS RDS offers a `deletion_protection` flag that prevents the database instance from
being deleted. It was set to `false`. A single boolean that would have stopped the
entire disaster was left at its default value.

**The fix:** In your Azure environment, apply `CanNotDelete` resource locks to every
production database. Unlike AWS's deletion protection flag (which Terraform can disable
in the same apply), Azure Resource Locks operate at the ARM level and require explicit
manual removal before deletion can proceed.

#### Failure 5: Backups Tied to Instance Lifecycle

AWS RDS automated snapshots are deleted when the RDS instance is deleted. The engineer
had backups configured — but they vanished along with the database. Only a separate
manual backup (created independently) survived and enabled recovery.

**The fix:** In your Azure environment, use Azure Backup Vaults to maintain independent,
immutable backups that exist outside the resource's lifecycle. Azure Backup Vaults
decouple backup storage from resource existence entirely — your backups survive even if
the database is deleted.

---

## Learning Objectives

By working through this exercise (or reading this guide), you will:

1. **Understand how Terraform state drift leads to infrastructure destruction** — see
   firsthand what happens when Terraform loses track of real-world resources
2. **Experience (safely) the chain of failures** that destroyed a production database —
   the simulation walks through each step interactively
3. **Practice database recovery from backup** — restore a destroyed database and verify
   data integrity
4. **Implement Azure-equivalent guardrails** — resource locks, immutable backup vaults,
   and remote state backends
5. **Implement GitHub guardrails** — CODEOWNERS, Actions workflows for plan/apply/destroy,
   and environment approvals
6. **Configure AI agent guardrails** — Copilot CLI custom instructions, plan mode, and
   permission boundaries

---

## Defense-in-Depth: The Three Layers

No single guardrail is enough. The incident proved that. Deletion protection alone
wouldn't have helped if the AI agent had been instructed to disable it first. Remote
state alone wouldn't have prevented a deliberate `terraform destroy`. The answer is
**defense-in-depth** — multiple independent layers, each capable of stopping the
incident on its own.

```
┌──────────────────────────────────────────────────────────────┐
│                    DEFENSE IN DEPTH                           │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Layer 3: AI Agent Guardrails (Copilot CLI)            │  │
│  │  • Permission system • Plan mode • Custom instructions │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Layer 2: Workflow Guardrails (GitHub)            │  │  │
│  │  │  • CODEOWNERS • Actions CI/CD • Approvals        │  │  │
│  │  │  ┌────────────────────────────────────────────┐  │  │  │
│  │  │  │  Layer 1: Infrastructure Guardrails (Azure) │  │  │  │
│  │  │  │  • Resource locks • Immutable backups       │  │  │  │
│  │  │  │  • Remote state  • Azure Policy             │  │  │  │
│  │  │  └────────────────────────────────────────────┘  │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Each layer can independently stop the incident.             │
│  Together, they make accidental destruction nearly            │
│  impossible.                                                 │
└──────────────────────────────────────────────────────────────┘
```

---

### Layer 1: Infrastructure Guardrails (Azure)

Infrastructure guardrails operate at the **platform level**. They don't care who or what
is issuing the command — a human, a CI/CD pipeline, or an AI agent. If a resource lock
says "you cannot delete this," the operation fails. Period.

#### Resource Locks

Azure Resource Locks provide two levels of protection:

- **`CanNotDelete`** — The resource can be modified but not deleted. Any deletion attempt
  (including via Terraform) returns a `ScopeLocked` error.
- **`ReadOnly`** — The resource cannot be modified or deleted. Useful for critical
  configuration that should never change.

In the context of this incident, a `CanNotDelete` lock on the PostgreSQL database would
have caused `terraform destroy` to fail immediately. The AI agent would have received an
error, and the database would have survived.

```hcl
resource "azurerm_management_lock" "db_no_delete" {
  name       = "prevent-db-deletion"
  scope      = azurerm_postgresql_flexible_server.production.id
  lock_level = "CanNotDelete"
  notes      = "Production database — removal requires manual lock deletion"
}
```

**Key insight:** Resource locks must be explicitly removed before the protected resource
can be deleted. This creates a deliberate, two-step process that prevents accidental
destruction.

#### Immutable Backup Vaults

This is where Azure has a significant architectural advantage over AWS for this failure
mode. AWS RDS automated snapshots are **tied to the instance lifecycle** — when the
instance is deleted, the automated snapshots go with it. Azure Backup Vaults store
backups **independently** of the source resource.

Even if someone successfully deletes the database (bypassing locks, policies, and all
other guardrails), the backups in the vault survive. The vault can also be configured
with **immutability policies** that prevent even administrators from deleting backups
before their retention period expires.

```hcl
resource "azurerm_backup_policy_postgresql_flexible_server" "production" {
  name                = "production-db-backup-policy"
  vault_id            = azurerm_recovery_services_vault.production.id
  backup_repeating_time_intervals = ["R/2024-01-01T02:00:00+00:00/P1D"]

  default_retention_rule {
    life_cycle {
      duration      = "P30D"
      data_store_type = "VaultStore"
    }
  }
}
```

#### Remote State Backend

The root cause of the entire incident was a missing state file. Remote state backends
solve this by storing the state in a shared, locked, versioned location:

- **Azure Blob Storage** with lease-based locking (built-in, no separate lock table
  needed)
- **State versioning** through blob snapshots, enabling rollback if state is corrupted
- **Encryption at rest** protects sensitive values in the state file

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "prodtfstate"
    container_name       = "tfstate"
    key                  = "production/database.tfstate"
  }
}
```

With remote state, switching laptops is a non-event. The state is always in the cloud,
always locked during operations, and always versioned for recovery.

#### Azure Policy

For organizational-scale enforcement, Azure Policy can deny operations that violate
your rules across an entire subscription or management group:

- Deny deletion of resources tagged `environment: production`
- Require deletion protection on all database resources
- Enforce backup configuration on all data stores
- Require resource locks on production resource groups

---

### Layer 2: Workflow Guardrails (GitHub)

While infrastructure guardrails protect resources at the platform level, workflow
guardrails ensure that **changes go through a review process** before they reach
production. This is the layer that prevents mistakes from being deployed in the first
place.

#### CODEOWNERS

The `CODEOWNERS` file ensures that changes to critical files require review from
specific teams:

```
# All Terraform files require infrastructure team review
*.tf                           @infra-team
*.tfvars                       @infra-team

# Workflow changes require security team review
.github/workflows/             @security-team

# Production infrastructure requires both teams
infrastructure/production/     @infra-team @security-team
```

In the incident, the AI agent made changes to Terraform files and executed them
without any human review. With CODEOWNERS and branch protection, those changes
would have required a pull request reviewed by the infrastructure team.

#### GitHub Actions: Plan on PR

Every pull request that modifies Terraform files should automatically run
`terraform plan` and post the output as a PR comment. This gives reviewers a
clear picture of what will change:

- **New resources** being created (were duplicates spotted?)
- **Modified resources** (are the changes expected?)
- **Destroyed resources** (🚨 this is the red flag)

The plan workflow is **read-only** — it cannot make changes. It only generates
the plan and displays it for review.

#### Environment Approvals for Apply

GitHub Environments can require **manual approval** before a workflow targeting
that environment can proceed. For production infrastructure:

1. A PR is merged with the reviewed Terraform changes
2. The `terraform-apply` workflow triggers
3. It targets the `production` environment
4. GitHub pauses and notifies the required reviewers
5. A reviewer inspects the plan output and approves (or rejects)
6. Only then does `terraform apply` execute

This creates a deliberate, auditable approval chain that prevents both accidental
and unauthorized changes.

#### Manual-Only Destroy Workflow

The `terraform destroy` workflow should be:

- **`workflow_dispatch` only** — it can never trigger automatically
- **Requires an issue link** — you must document _why_ destruction is needed
- **Requires a confirmation input** — type the environment name to proceed
- **Requires environment approval** — a human reviewer must approve
- **Logs everything** — full audit trail in GitHub Actions

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Type "production" to confirm destruction'
        required: true
      issue_url:
        description: 'Link to the issue authorizing this destruction'
        required: true
```

In the incident, `terraform destroy` was run casually by an AI agent in a terminal.
With this workflow, destruction requires explicit intent, documentation, and approval.

#### Branch Protection

Branch protection rules prevent direct pushes to production branches:

- Require pull request reviews before merging
- Require status checks (the plan workflow) to pass
- Require conversation resolution before merging
- Restrict who can push to the branch

---

### Layer 3: AI Agent Guardrails (Copilot CLI)

The third layer addresses the most novel aspect of this incident: an AI coding agent
with unrestricted access ran a destructive command without human review. This is a new
class of risk that traditional infrastructure management didn't anticipate.

GitHub Copilot CLI is designed with safety as a core principle.

#### Permission System

Every command Copilot CLI suggests is **shown to the user before execution**. The agent
cannot silently run commands in the background. When it wants to execute something, you
see exactly what it plans to run and must explicitly approve it.

This is the fundamental difference from the incident. The AI agent in the incident had
autonomous terminal access — it could execute `terraform destroy` without showing the
command first. Copilot CLI would display:

```
🤖 I'd like to run: terraform destroy
   This will destroy all resources managed by Terraform.
   [Allow] [Deny] [Edit]
```

The human always makes the final decision.

#### Plan Mode

Plan mode tells Copilot CLI to create a detailed, reviewable plan before taking any
action. Instead of executing commands one at a time, the agent outlines its entire
approach and waits for approval of the plan as a whole.

For infrastructure work, this means you can review the _sequence_ of operations before
any of them execute — catching dangerous patterns like "apply then destroy" before
they start.

#### Custom Instructions

Custom instructions (`.github/copilot-instructions.md`) let you define domain-specific
safety rules that Copilot CLI follows:

```markdown
## Infrastructure Safety Rules

- NEVER run `terraform destroy` without explicit confirmation
- ALWAYS run `terraform plan` first and display the output
- NEVER modify terraform.tfstate files directly
- ALWAYS verify the target environment before any Terraform operation
- Flag any plan that shows resource destruction for human review
```

These instructions act as a persistent safety context — the agent carries them across
every interaction, ensuring infrastructure-specific caution even when the human might
forget.

#### Directory Scoping

You can limit which directories and files Copilot CLI can access, preventing the agent
from accidentally modifying production configurations when working on development tasks.

#### The Key Contrast

In the original incident, the failure chain was:

1. AI agent had full terminal access ✗
2. AI agent executed `terraform destroy` without showing the command first ✗
3. No confirmation was requested before a destructive operation ✗
4. The human learned about the destruction only after it happened ✗

With Copilot CLI's guardrails:

1. Every command is shown before execution ✓
2. `terraform destroy` would be flagged and require explicit approval ✓
3. Custom instructions would add additional warnings ✓
4. Plan mode would reveal the full sequence of operations upfront ✓

---

## The Exercise: Six Scenarios

This exercise walks you through the incident and its prevention across six hands-on
scenarios. Each builds on the last:

| # | Scenario | What You Do | What You Learn |
|---|----------|-------------|----------------|
| 1 | **Setup Production** | Build the simulated production environment | How the production database is structured |
| 2 | **Simulate Incident** | Walk through the exact failure chain | How compounding failures lead to disaster |
| 3 | **Recover Database** | Restore from the pre-incident backup | Why independent backups are essential |
| 4 | **Azure Guardrails** | Implement resource locks, backup vaults, remote state | Platform-level protection mechanisms |
| 5 | **GitHub Guardrails** | Create CODEOWNERS, CI/CD workflows, environment approvals | Process-level protection mechanisms |
| 6 | **Copilot CLI Guardrails** | Configure custom instructions and safety rules | AI agent-level protection mechanisms |

---

## Discussion Questions

These questions are designed for team discussions, workshops, or individual reflection
after completing the exercise.

### 1. Breaking the Chain

> At which point in the failure chain would each guardrail have stopped the incident?

Map each guardrail (resource locks, remote state, CODEOWNERS, environment approvals,
Copilot CLI permissions) to the specific failure it would have prevented. Which
guardrails overlap in coverage?

### 2. Minimum Viable Safety

> What's the minimum set of guardrails needed to prevent this class of incident?

If you could only implement three guardrails, which three would you choose and why?
Consider cost, complexity, and coverage.

### 3. AI Agent Authority

> Should AI agents ever be allowed to run destructive infrastructure commands?

Consider the spectrum: fully autonomous → autonomous with guardrails → human-in-the-loop
→ advisory only. Where should the line be for different environments (dev, staging,
production)?

### 4. Speed vs. Safety

> How do you balance speed and convenience with safety in infrastructure management?

The AI agent was being used to _move faster_. The guardrails in this exercise add
friction. How do you find the right balance? When is friction a feature?

### 5. Backup Independence

> What backup strategy ensures recovery even if the platform's own backups are lost?

The incident revealed that AWS RDS automated snapshots are deleted with the instance.
Design a backup strategy that survives any single point of failure — including the
cloud provider's own backup system.

### 6. Testing Guardrails

> How would you test that your guardrails actually work?

A guardrail you've never tested is like a backup you've never restored — it's a hope,
not a guarantee. Consider chaos engineering approaches: scheduled "game days" where you
deliberately attempt to bypass your own protections.

---

## Key Takeaways

### 1. Never Store Terraform State Locally

Local state files are single points of failure. They don't survive laptop changes,
disk failures, or accidental deletion. Use remote backends with locking and versioning.
This is the single most impactful change from this incident.

### 2. Never Co-locate Unrelated Infrastructure

When your application containers and your production database are in the same Terraform
project, a single `terraform destroy` can wipe out both. Separate projects create
separate blast radii. The database should be managed independently with its own state,
its own review process, and its own approval chain.

### 3. Never Delegate Destructive Operations to AI Without Review

AI agents are powerful tools, but they optimize for _completing the task_ — not for
_questioning whether the task should be done_. Human-in-the-loop review is essential
for any operation that could cause data loss. Copilot CLI's permission system exists
precisely for this reason.

### 4. Enable Deletion Protection on All Production Databases

A single boolean flag — `deletion_protection = true` — would have stopped this entire
incident. Create deliberate friction for destructive operations on production resources.
If removing the protection requires a separate, explicit action, accidental destruction
becomes much harder.

### 5. Maintain Independent Backups

Your backup strategy must survive the deletion of the resource being backed up. If your
backups are tied to the resource lifecycle (as AWS RDS automated snapshots are), they
provide zero protection against the exact scenario you most need protection from. Use
independent backup vaults with immutability policies.

### 6. Test Your Recovery Path

A backup you haven't tested is just a hope. Regularly restore from backup in a
non-production environment. Verify row counts, data integrity, and application
functionality. Time the process. Document the steps. The middle of an incident is
the worst time to learn your recovery procedure.

---

## Your Azure Environment vs. the Original AWS Incident

Understanding how your Azure protections compare to the AWS setup in the original incident:

| Protection | Your Azure Environment | Original Incident (AWS) | Why This Matters |
|-----------|------------------------|------------------------|-----------------|
| **Deletion protection** | Resource Locks (`CanNotDelete`) — operates at the ARM level, outside Terraform's control plane | RDS flag (`deletion_protection`) — Terraform can disable and delete in the same apply | In your environment, even a rogue `terraform destroy` is blocked without manual lock removal |
| **Backup independence** | Backup Vault stores independently of the source resource | Automated snapshots deleted with the RDS instance | Your backups survive resource deletion by design |
| **State locking** | Blob Storage with lease locking (built-in, no extra resources) | S3 + DynamoDB (separate table to provision) | Simpler setup in your environment for equivalent protection |
| **Policy enforcement** | Azure Policy with `deny`, `audit`, and `remediate` effects | SCPs (Organizations) | Similar coverage; Azure Policy also auto-remediates non-compliant resources |
| **Emergency support** | Professional Direct: ~$1,000/mo; Standard: $100/mo | Business: ~$100/mo + 10% of bill | AWS was cheaper for this incident's recovery, but your vault-based backups reduce the need for support-assisted recovery |

> **Critical insight for your environment:** The original incident's worst outcome — losing automated
> backups when the database was deleted — cannot happen with Azure Backup Vaults. Your vault-based
> architecture decouples backup lifecycle from resource lifecycle by default, providing a stronger
> safety net against `terraform destroy` disasters.

---

## Applying These Lessons in Your Azure Environment

### Start Here (Quick Wins)

These changes take less than a day and prevent the highest-impact failures. In your Azure environment:

- [ ] Apply `CanNotDelete` resource locks to all production databases (PostgreSQL Flexible Server, Cosmos DB, etc.)
- [ ] Move Terraform state to an Azure Blob Storage backend with lease locking
- [ ] Add a `CODEOWNERS` file requiring review for infrastructure changes
- [ ] Add `.github/copilot-instructions.md` with infrastructure safety rules

### Build Next (Medium Effort)

These changes require more planning but provide deeper protection in your Azure environment:

- [ ] Separate infrastructure into independent Terraform projects by blast radius
- [ ] Implement GitHub Actions workflows for plan-on-PR and gated apply
- [ ] Configure environment protection rules with required reviewers
- [ ] Set up Azure Backup Vaults with immutability policies for all production data stores
- [ ] Enable soft-delete on Azure Key Vault and Storage Accounts

### Mature Practice (Ongoing)

These practices require cultural change and continuous investment:

- [ ] Run regular "game day" exercises testing guardrails and recovery procedures
- [ ] Implement Azure Policy for organization-wide enforcement across subscriptions and management groups
- [ ] Conduct periodic access reviews for AI agent permissions and tool configurations
- [ ] Practice recovery drills — time them, document them, improve them
- [ ] Use Azure Chaos Studio to validate resilience under failure conditions

---

## Further Reading

### The Original Incident
- [How I Dropped Our Production Database — Alexey Grigorev](https://alexeyondata.substack.com/p/how-i-dropped-our-production-database)

### Terraform & State Management
- [Terraform Remote State Documentation](https://developer.hashicorp.com/terraform/language/state/remote)
- [Terraform State Locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [Backend Configuration: azurerm](https://developer.hashicorp.com/terraform/language/backend/azurerm)

### Azure Protection Mechanisms
- [Azure Resource Locks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources)
- [Azure Backup Overview](https://learn.microsoft.com/en-us/azure/backup/backup-overview)
- [Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/overview)

### GitHub Guardrails
- [GitHub Copilot CLI Documentation](https://docs.github.com/copilot/concepts/agents/about-copilot-cli)
- [GitHub Actions Environments](https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [CODEOWNERS Documentation](https://docs.github.com/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [Branch Protection Rules](https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)

### Resilience & Chaos Engineering
- [Principles of Chaos Engineering](https://principlesofchaos.org/)
- [Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview)

---

<p align="center">
  <em>
    Built for the <strong>Preventing Production Database Disasters</strong> GitHub Skills exercise.<br/>
    Because the best time to learn from a disaster is before it happens to you.
  </em>
</p>
