<!--
  🛡️ Preventing Production Database Disasters
  A GitHub Skills Exercise
-->

<header>

# 🛡️ Preventing Production Database Disasters

_An interactive GitHub Skills exercise that teaches you to protect production infrastructure from accidental destruction by AI-assisted tools._

</header>

## Welcome

Based on a [real incident](https://alexeyondata.substack.com/p/how-i-dropped-our-production-database) where an AI coding agent ran `terraform destroy` and wiped a production database containing **1.9 million rows** of student data, this exercise lets you safely experience the failure, practice recovery, and implement guardrails.

- **Who is this for**: DevOps engineers, platform engineers, SREs, and developers working with Infrastructure as Code.
- **What you'll learn**: Terraform state management, Azure resource locks, GitHub Actions IaC pipelines, CODEOWNERS, and Copilot CLI's human-in-the-loop security model.
- **What you'll build**: A defense-in-depth guardrail strategy combining Azure, GitHub, and AI agent protections.
- **Prerequisites**: Docker Desktop, Terraform CLI (v1.0+), Git. Optional: GitHub Copilot CLI for Step 6.
- **How long**: This exercise takes 1.5–2 hours to complete.

In this exercise, you will:

1. 🏗️ Build a simulated "production" database with 55,000+ rows
2. 💥 Simulate the exact incident that destroyed a real production database
3. 🔧 Practice database recovery from backup
4. 🔒 Study Azure guardrails (resource locks, immutable backups, remote state)
5. 🛡️ Implement GitHub guardrails (CODEOWNERS, Actions workflows, environment approvals)
6. 🤖 Configure Copilot CLI guardrails (custom instructions, plan mode)

### How to start this exercise

Simply copy the exercise to your account, then give your favorite Octocat (Mona) **about 20 seconds** to prepare the first lesson, then **refresh the page**.

[![Copy Exercise](https://img.shields.io/badge/Copy%20Exercise-%E2%86%92-1f883d?style=for-the-badge&logo=github&labelColor=197935)](https://github.com/new?template_owner=ragmha&template_name=prod-db-incident-sim&owner=%40me&name=skills-prod-db-incident-sim&description=Exercise:+Preventing+Production+Database+Disasters&visibility=public)

> **Having trouble?** Check the [Actions tab](../../actions) — if a job failed, please [open an issue](../../issues/new).

---

## How It Works

This exercise uses the [GitHub Skills exercise-toolkit](https://github.com/skills/exercise-toolkit) pattern:

1. **Copy the template** → GitHub Actions creates an exercise Issue with Step 1
2. **Complete each step** → Push evidence files to prove completion
3. **Auto-progression** → Workflows validate your work and post the next step
4. **All 6 steps done** → 🎉 Congratulations posted, issue closed

Everything runs **locally in Docker** (PostgreSQL + Azurite) — **zero cloud cost**, no Azure subscription needed.

## Architecture

### 🏗️ Exercise Environment

Everything runs locally in Docker — zero cloud cost, fully safe to destroy and rebuild.

```
                    Learner's Terminal
         ┌────────────────────────────────────┐
         │ make setup | terraform | git push  │
         └──────┬────────────┬──────────┬─────┘
                │            │          │
       make seed│  terraform │   git push evidence/
       make     │  plan      │          │
       recover  │  apply     │          │
                │  destroy   │          │
     ┌──────────▼────────────▼───┐      │
     │     Docker Compose        │      │
     │                           │      │
     │  ┌─────────────────────┐  │      │
     │  │ PostgreSQL 16       │  │      │
     │  │ course_platform     │  │      ▼
     │  │ 55K+ rows, 7 tables │  │  ┌──────────┐
     │  └─────────────────────┘  │  │  GitHub  │
     │                           │  │  Actions │
     │  ┌─────────────────────┐  │  │          │
     │  │ Azurite             │  │  │ validate │
     │  │ Azure Blob Storage  │  │  │ + post   │
     │  │ (TF Remote State)   │  │  │ next step│
     │  └─────────────────────┘  │  └──────────┘
     │                           │
     └───────────────────────────┘

 PostgreSQL = Azure Database for PostgreSQL Flexible Server
 Azurite    = Azure Blob Storage (Terraform remote state)
 Terraform  = azurerm provider throughout
```

### 💥 The Incident — Failure Chain

This is the exact sequence from a real AWS incident. The same failure chain applies identically to Azure — replace RDS with PostgreSQL Flexible Server, S3 with Blob Storage, ECS with Container Apps.

```mermaid
sequenceDiagram
    participant E as 👷 Engineer
    participant AI as 🤖 AI Agent
    participant TF as Terraform
    participant AWS as ☁️ AWS Production

    Note over E: Thursday ~10PM — New laptop, no state file
    E->>AI: Deploy website changes with Terraform
    AI->>TF: terraform plan
    Note over TF: ⚠️ No state file!<br/>Plans to CREATE everything
    TF-->>AI: Plan: 17 to add, 0 to destroy
    AI->>TF: terraform apply
    TF->>AWS: Creates DUPLICATE resources

    E->>AI: Why are we creating so many resources?
    AI-->>E: Terraform believed nothing existed

    Note over E: Transfers Terraform archive from old laptop
    E->>AI: Clean up the duplicate resources
    AI->>AI: Unpacks archive...<br/>⚠️ Replaces empty state<br/>with PRODUCTION state
    AI-->>E: I'll do terraform destroy — cleaner

    rect rgb(255, 230, 230)
        Note over AI,AWS: 💀 THE CRITICAL MOMENT
        AI->>TF: terraform destroy -auto-approve
        TF->>AWS: Destroys VPC, RDS, ECS, ALB, Bastion
        Note over AWS: 1.9M rows DELETED<br/>Automated snapshots ALSO DELETED
    end

    Note over E: Thursday ~11PM — Discovers destruction
    E->>AWS: Check for backups...
    AWS-->>E: ❌ Snapshots deleted with the database

    Note over E: Friday ~12AM — Upgrades to Business Support
    Note over E: Friday ~10PM (24 hours later)
    AWS-->>E: ✅ Snapshot restored from internal backup
    Note over AWS: 1,943,200 rows restored
```

### 🛡️ Defense-in-Depth — Three Layers of Protection

The exercise teaches you to implement guardrails at **every layer** so no single failure can reach production:

```
 ╔════════════════════════════════════════════════════╗
 ║  LAYER 3: AI Agent Guardrails (Copilot CLI)       ║
 ║                                                    ║
 ║  ┌──────────────────┐  ┌──────────────────┐       ║
 ║  │ Permission       │  │ Plan Mode        │       ║
 ║  │ Prompts          │  │ Review before    │       ║
 ║  │ Every cmd shown  │  │ any action       │       ║
 ║  └──────────────────┘  └──────────────────┘       ║
 ║  ┌──────────────────┐  ┌──────────────────┐       ║
 ║  │ Custom           │  │ Directory        │       ║
 ║  │ Instructions     │  │ Scoping          │       ║
 ║  │ Safety rules     │  │ Restrict access  │       ║
 ║  └──────────────────┘  └──────────────────┘       ║
 ╠════════════════════════════════════════════════════╣
                  │
                  │ Blocks autonomous destructive commands
                  ▼
 ╔════════════════════════════════════════════════════╗
 ║  LAYER 2: Workflow Guardrails (GitHub)             ║
 ║                                                    ║
 ║  ┌──────────────────┐  ┌──────────────────┐       ║
 ║  │ CODEOWNERS       │  │ Actions:         │       ║
 ║  │ Require review   │  │ terraform plan   │       ║
 ║  │ for *.tf files   │  │ on every PR      │       ║
 ║  └──────────────────┘  └──────────────────┘       ║
 ║  ┌──────────────────┐  ┌──────────────────┐       ║
 ║  │ Environment      │  │ Manual Destroy   │       ║
 ║  │ Approvals        │  │ Workflow         │       ║
 ║  │ Gate tf apply    │  │ Issue + confirm  │       ║
 ║  └──────────────────┘  └──────────────────┘       ║
 ╠════════════════════════════════════════════════════╣
                  │
                  │ Requires human review and approval
                  ▼
 ╔════════════════════════════════════════════════════╗
 ║  LAYER 1: Infrastructure Guardrails (Azure)       ║
 ║                                                    ║
 ║  ┌──────────────────┐  ┌──────────────────┐       ║
 ║  │ Resource Locks   │  │ Immutable        │       ║
 ║  │ CanNotDelete on  │  │ Backup Vault     │       ║
 ║  │ production DB    │  │ Survives delete  │       ║
 ║  └──────────────────┘  └──────────────────┘       ║
 ║  ┌──────────────────┐  ┌──────────────────┐       ║
 ║  │ Remote State     │  │ Azure Policy     │       ║
 ║  │ Blob Storage +   │  │ Enforce          │       ║
 ║  │ lease locking    │  │ standards        │       ║
 ║  └──────────────────┘  └──────────────────┘       ║
 ╠════════════════════════════════════════════════════╣
                  │
                  │ Platform-level last line of defense
                  ▼
            ┌────────────────┐
            │   Production   │
            │   Database     │
            │   1.9M rows    │
            └────────────────┘
```

### 📂 Repository Structure

```
prod-db-incident-sim/
├── .github/
│   ├── workflows/          # 7 exercise progression workflows (0-start → step 6)
│   ├── steps/              # 6 step content files (posted to exercise issue)
│   └── copilot-instructions.md  # Repo-level Copilot CLI safety rules
├── infrastructure/
│   ├── production/         # Azure Terraform configs (azurerm provider)
│   ├── incident/           # Incident simulation (no state file + simulate.sh)
│   └── guardrails/
│       ├── azure/          # Resource locks, backup vault, remote state (TF)
│       └── templates/      # Learner-completable templates (CODEOWNERS, workflows)
├── database/
│   ├── seed-data.sql       # 55K+ rows of course management data
│   └── backup/             # Pre-created backup for recovery exercise
├── solutions/              # Reference implementations (peek if stuck)
├── docs/                   # Companion guide, AWS↔Azure mapping, instructor notes
├── docker-compose.yml      # PostgreSQL + Azurite (Azure Storage emulator)
└── Makefile                # make setup | seed | simulate-incident | recover | reset
```

## Quick Reference

| Command | Description |
|---|---|
| `make setup` | Start Docker services (PostgreSQL + Azurite) |
| `make seed` | Populate database with 55K+ rows |
| `make verify` | Check database integrity |
| `make simulate-incident` | 💥 Run the incident simulation (Step 2) |
| `make recover` | 🔧 Restore from backup (Step 3) |
| `make reset` | Reset everything to initial state |
| `make help` | Show all available commands |

## Documentation

| Document | Description |
|---|---|
| [Companion Guide](docs/COMPANION-GUIDE.md) | Full educational narrative and key takeaways |
| [AWS → Azure Mapping](docs/AWS-AZURE-MAPPING.md) | Detailed service comparison |
| [Instructor Notes](docs/INSTRUCTOR-NOTES.md) | Workshop facilitation guide |

## Based On

This exercise is inspired by Alexey Grigorev's transparent and invaluable post: **[How I Dropped Our Production Database and What I Did Next](https://alexeyondata.substack.com/p/how-i-dropped-our-production-database)**. We deeply respect the author's willingness to share this experience for the benefit of the engineering community.

---

© 2025 • [Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/code_of_conduct.md) • [MIT License](LICENSE)
