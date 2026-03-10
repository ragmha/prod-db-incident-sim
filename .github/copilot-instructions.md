# Copilot Instructions — Production Database Disaster Exercise

## About This Repository

This is a GitHub Skills exercise that teaches engineers how to prevent
production database disasters when using AI-assisted infrastructure tools.
It simulates a real incident where an AI coding agent destroyed production
infrastructure by running `terraform destroy` without proper guardrails.

## Safety Rules for This Exercise

### Terraform Operations
- **Never** execute `terraform apply` or `terraform destroy` without showing the full plan first
- **Always** explain what each Terraform command will do before suggesting it
- When working with `infrastructure/production/`, treat it as real production — warn about destructive operations
- When working with `infrastructure/incident/`, this is the simulation directory — destructive operations are expected here as part of the exercise

### Docker Operations
- The exercise uses Docker containers (PostgreSQL for the production database, Azurite for Azure Blob Storage)
- It is safe to start, stop, and reset these containers
- Use `make` targets when available instead of raw docker commands

### Exercise Flow
- This exercise has 6 steps, each tracked through a GitHub Issue
- Learners push "evidence" files to prove step completion
- Do not skip steps or reveal future step content prematurely

### File Handling
- Do not modify files in `.github/workflows/` — these are the exercise validation workflows
- Do not modify files in `.github/steps/` — these are the step instructions
- Template files in `infrastructure/guardrails/templates/` are meant to be completed by learners
- Solution files in `solutions/` should not be shown unless the learner explicitly asks for help

### General
- Prefer `make` targets over raw commands for common operations
- Always verify which directory you're in before running Terraform commands
- Explain the "why" behind safety practices, not just the "what"
