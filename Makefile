# Lab commands. Run them from the repository root in the Codespace, or on any
# Linux or macOS machine with Docker, Terraform, and Node.js. Run `make` for help.
SHELL := bash
LAB := scripts/lab
.DEFAULT_GOAL := help
# The separate Terraform state store from docker-compose.yml, for a pg backend.
PG_CONN_STR ?= postgres://terraform@127.0.0.1:5433/terraform_state?sslmode=disable
export PG_CONN_STR
.PHONY: help doctor setup verify replay snapshots recover drill plan plan-check apply agent-replay evidence db-shell teardown reset

help: ## Show the lab commands
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN { FS = ":.*## " } { printf "  %-14s %s\n", $$1, $$2 }'

doctor: ## Check the toolchain without starting anything
	@bash $(LAB)/doctor.sh

setup: ## Build production: database, course data, and backups
	@bash $(LAB)/setup.sh

verify: ## Show production row counts
	@bash database/verify.sh

replay: ## Replay the incident with real Terraform commands (destructive)
	@bash $(LAB)/replay-incident.sh

snapshots: ## List the automated backups on the database server
	@bash $(LAB)/control-plane.sh list-snapshots course_platform

recover: ## Restore production from the newest surviving backup
	@bash $(LAB)/recover.sh

drill: ## Restore the independent backup into a scratch database and verify it
	@bash $(LAB)/drill.sh

plan: ## Preview infrastructure changes without saving or applying them
	@terraform -chdir=infrastructure/lab plan -input=false

plan-check: ## Save a plan for review; fail if it deletes or replaces anything
	@bash $(LAB)/plan-check.sh

apply: ## Apply exactly the plan saved by plan-check
	@bash $(LAB)/apply.sh

agent-replay: ## Replay the incident's agent tool calls through .github/hooks
	@node scripts/replay-agent.mjs

evidence: ## Produce the drill, incident replay, and agent replay evidence
	@bash $(LAB)/evidence.sh

db-shell: ## Open psql on the production database
	@docker compose exec postgres psql -U admin -d course_platform

teardown: ## Delete the lab's containers, data, state, and backups
	docker compose down --volumes --remove-orphans
	rm -rf .lab infrastructure/lab/.terraform infrastructure/lab/terraform.tfstate infrastructure/lab/terraform.tfstate.backup

reset: ## Rebuild a clean lab (teardown, then setup)
	@$(MAKE) --no-print-directory teardown
	@$(MAKE) --no-print-directory setup
