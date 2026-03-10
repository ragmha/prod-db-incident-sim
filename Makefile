# =============================================================================
# Preventing Production Database Disasters — Exercise Makefile
# =============================================================================
# Quick commands for running the exercise scenarios.
# Each target maps to an exercise step.
# =============================================================================

.PHONY: setup teardown reset seed health-check \
        simulate-incident recover verify \
        help

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
COMPOSE          := docker compose
DB_CONTAINER     := prod-db-incident-sim-postgres-1
DB_USER          := admin
DB_NAME          := course_platform
DB_PASSWORD      := production_secret_2024
PSQL             := $(COMPOSE) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME)

# ---------------------------------------------------------------------------
# Help (default target)
# ---------------------------------------------------------------------------
help: ## Show this help message
	@echo ""
	@echo "🛡️  Preventing Production Database Disasters — Exercise Commands"
	@echo "================================================================"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------------------
# Step 1: Setup Production
# ---------------------------------------------------------------------------
setup: ## 🏗️  Start Docker services (PostgreSQL + Azurite)
	@echo "🏗️  Starting production environment..."
	$(COMPOSE) up -d
	@echo "⏳ Waiting for services to be healthy..."
	@sleep 5
	$(COMPOSE) ps
	@echo ""
	@echo "✅ Services are running! Next: run 'make seed' to populate the database."

seed: ## 🌱 Seed the database with 50K+ rows of course data
	@echo "🌱 Seeding production database..."
	$(COMPOSE) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -f /dev/stdin < database/seed-data.sql
	@echo ""
	@echo "✅ Database seeded! Verifying..."
	@$(MAKE) verify

verify: ## ✅ Verify database has expected data
	@echo "📊 Verifying production data..."
	@echo "---"
	@$(PSQL) -c "SELECT 'courses' AS table_name, COUNT(*) AS row_count FROM courses UNION ALL SELECT 'students', COUNT(*) FROM students UNION ALL SELECT 'enrollments', COUNT(*) FROM enrollments UNION ALL SELECT 'homework_questions', COUNT(*) FROM homework_questions UNION ALL SELECT 'courses_answer', COUNT(*) FROM courses_answer UNION ALL SELECT 'leaderboard', COUNT(*) FROM leaderboard UNION ALL SELECT 'login_providers', COUNT(*) FROM login_providers ORDER BY table_name;"
	@echo "---"
	@echo ""
	@echo "💾 Total rows in courses_answer (the critical table):"
	@$(PSQL) -t -c "SELECT COUNT(*) FROM courses_answer;"

health-check: ## 🩺 Check if all Docker services are healthy
	@echo "🩺 Checking service health..."
	$(COMPOSE) ps
	@echo ""
	@echo "PostgreSQL:"
	@$(PSQL) -c "SELECT 'connected' AS status;" 2>/dev/null && echo "  ✅ Connected" || echo "  ❌ Not available"
	@echo ""
	@echo "Azurite (Azure Storage):"
	@curl -s http://localhost:10000/ > /dev/null 2>&1 && echo "  ✅ Running" || echo "  ❌ Not available"

# ---------------------------------------------------------------------------
# Step 2: Simulate the Incident
# ---------------------------------------------------------------------------
simulate-incident: ## 💥 Run the incident simulation (Step 2)
	@echo "💥 Starting incident simulation..."
	@echo "⚠️  This will DESTROY the database contents (safely in Docker)!"
	@echo ""
	@bash infrastructure/incident/simulate.sh

# ---------------------------------------------------------------------------
# Step 3: Recovery
# ---------------------------------------------------------------------------
recover: ## 🔧 Restore database from backup (Step 3)
	@echo "🔧 Restoring database from backup..."
	$(COMPOSE) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -f /dev/stdin < database/backup/production-backup.sql
	@echo ""
	@echo "✅ Restore complete! Verifying..."
	@$(MAKE) verify

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------
teardown: ## 🗑️  Stop and remove all Docker containers and volumes
	@echo "🗑️  Tearing down all services..."
	$(COMPOSE) down -v
	@echo "✅ All services removed."

reset: ## 🔄 Reset everything to initial state (teardown + setup + seed)
	@echo "🔄 Resetting to initial state..."
	@$(MAKE) teardown
	@$(MAKE) setup
	@sleep 3
	@$(MAKE) seed
	@echo ""
	@echo "✅ Reset complete! Ready for another run."

db-shell: ## 🐘 Open a PostgreSQL interactive shell
	$(COMPOSE) exec postgres psql -U $(DB_USER) -d $(DB_NAME)

save-evidence: ## 📸 Save current database state to evidence file
	@echo "📸 Saving evidence..."
	@mkdir -p evidence
	@$(PSQL) -c "SELECT 'courses_answer' AS table_name, COUNT(*) AS row_count FROM courses_answer;" > evidence/db-state.txt
	@$(PSQL) -c "SELECT COUNT(DISTINCT student_id) AS unique_students FROM courses_answer;" >> evidence/db-state.txt
	@echo "Captured at: $$(date -u)" >> evidence/db-state.txt
	@echo "✅ Evidence saved to evidence/db-state.txt"
