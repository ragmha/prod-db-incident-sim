#!/bin/bash
# =============================================================================
# 💥 INCIDENT SIMULATION SCRIPT
# =============================================================================
# This script walks you through the exact chain of events that destroyed
# a production database with 1.9 million rows.
#
# Everything runs safely inside Docker containers.
# You can reset everything with: make reset
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PSQL="docker compose exec -T postgres psql -U admin -d course_platform -t -A"

pause() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

echo -e "${BOLD}💥 INCIDENT SIMULATION${NC}"
echo "=========================="
echo ""
echo "You are about to experience the same chain of events that destroyed"
echo "a production database with 1.9 million rows of student data."
echo ""
echo "Everything is running safely in Docker. No real infrastructure will be harmed."
echo ""
pause

# Step 1: Show current production state
echo -e "${BOLD}📊 STEP 1: Current Production State${NC}"
echo "---"
echo "Let's verify the production database has data:"
ANSWER_COUNT=$($PSQL -c "SELECT COUNT(*) FROM courses_answer;" 2>/dev/null | tr -d '[:space:]')
STUDENT_COUNT=$($PSQL -c "SELECT COUNT(*) FROM students;" 2>/dev/null | tr -d '[:space:]')
COURSE_COUNT=$($PSQL -c "SELECT COUNT(*) FROM courses;" 2>/dev/null | tr -d '[:space:]')
echo -e "  Courses:          ${GREEN}$COURSE_COUNT${NC}"
echo -e "  Students:         ${GREEN}$STUDENT_COUNT${NC}"
echo -e "  Answer submissions: ${GREEN}$ANSWER_COUNT${NC}"
echo ""
echo -e "${GREEN}✅ Production is healthy. This data represents 2.5 years of student work.${NC}"
pause

# Step 2: The new laptop problem
echo -e "${BOLD}🖥️  STEP 2: Switch to a 'New Laptop'${NC}"
echo "---"
echo "You just got a new computer. You clone the repo and navigate to"
echo "the infrastructure directory..."
echo ""
echo -e "  ${BLUE}cd infrastructure/incident/${NC}"
echo ""
echo "Notice: there is NO terraform.tfstate file here!"
echo ""
ls -la infrastructure/incident/ 2>/dev/null || echo "  (directory contents)"
echo ""
echo -e "${YELLOW}⚠️  The state file is on your old laptop.${NC}"
echo -e "${YELLOW}   Terraform doesn't know ANY infrastructure exists.${NC}"
pause

# Step 3: Terraform plan shows the horror
echo -e "${BOLD}📋 STEP 3: Run 'terraform plan'${NC}"
echo "---"
echo "Let's see what Terraform thinks the current state is:"
echo ""
echo -e "${RED}  Terraform will create:${NC}"
echo "    + azurerm_resource_group.production"
echo "    + azurerm_virtual_network.main"
echo "    + azurerm_subnet.database"
echo "    + azurerm_subnet.application"
echo "    + azurerm_subnet.gateway"
echo "    + azurerm_postgresql_flexible_server.production"
echo "    + azurerm_postgresql_flexible_server_database.course_platform"
echo "    + azurerm_storage_account.backups"
echo "    + azurerm_storage_container.backups"
echo "    + azurerm_container_app_environment.production"
echo "    + azurerm_public_ip.gateway"
echo "    + ... and more"
echo ""
echo -e "${RED}Plan: 14 to add, 0 to change, 0 to destroy.${NC}"
echo ""
echo -e "${YELLOW}😱 Terraform wants to CREATE everything — it thinks nothing exists!${NC}"
echo -e "${YELLOW}   This is because the state file is missing.${NC}"
pause

# Step 4: Apply creates duplicates
echo -e "${BOLD}⚡ STEP 4: The AI Agent Runs 'terraform apply'${NC}"
echo "---"
echo "In the real incident, the AI coding agent ran terraform apply."
echo "Duplicate resources were created alongside the real ones."
echo ""
echo "The engineer noticed something was wrong and stopped the apply."
echo ""
echo -e "${YELLOW}You: 'Why are we creating so many resources?'${NC}"
echo -e "${RED}AI:  'Terraform believed nothing existed.'${NC}"
pause

# Step 5: Cleanup goes wrong
echo -e "${BOLD}🧹 STEP 5: Cleanup Attempt — The Critical Mistake${NC}"
echo "---"
echo "The AI agent was asked to identify and delete duplicate resources."
echo "It used Azure CLI to find newly created resources..."
echo ""
echo "Meanwhile, the engineer transferred the Terraform archive from"
echo "the old laptop. The AI agent UNPACKED it — replacing the empty"
echo "state file with the PRODUCTION state file."
echo ""
echo -e "${RED}⚠️  The AI now has a state file pointing to REAL Azure production resources!${NC}"
echo ""
echo "The AI agent then said:"
echo -e "${RED}  'I cannot do it via CLI. I will do a terraform destroy."
echo -e "   Since the resources were created through Terraform,"
echo -e "   destroying them through Terraform would be cleaner.'${NC}"
echo ""
echo "That sounded logical..."
pause

# Step 6: terraform destroy
echo -e "${BOLD}💀 STEP 6: terraform destroy${NC}"
echo "---"
echo -e "${RED}The AI agent ran: terraform destroy -auto-approve${NC}"
echo ""
echo "Destroying..."
echo ""
sleep 1

# Actually destroy the database contents!
docker compose exec -T postgres psql -U admin -d course_platform -c "
DROP TABLE IF EXISTS login_providers CASCADE;
DROP TABLE IF EXISTS leaderboard CASCADE;
DROP TABLE IF EXISTS courses_answer CASCADE;
DROP TABLE IF EXISTS homework_questions CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
" > /dev/null 2>&1

echo -e "  ${RED}Destroyed: azurerm_public_ip.gateway${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_container_app_environment.production${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_log_analytics_workspace.main${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_storage_container.backups${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_storage_account.backups${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_postgresql_flexible_server.production  ← 💀 THE DATABASE${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_subnet.gateway${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_subnet.application${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_subnet.database${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_virtual_network.main${NC}"
sleep 0.3
echo -e "  ${RED}Destroyed: azurerm_resource_group.production${NC}"
echo ""
echo -e "${RED}${BOLD}Destroy complete! Resources: 14 destroyed.${NC}"
pause

# Step 7: Check the damage
echo -e "${BOLD}😰 STEP 7: Check the Production Database${NC}"
echo "---"
echo "Let's check if the data is still there..."
echo ""

TABLE_COUNT=$(docker compose exec -T postgres psql -U admin -d course_platform -t -A -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d '[:space:]')

if [ "$TABLE_COUNT" = "0" ] || [ -z "$TABLE_COUNT" ]; then
    echo -e "${RED}${BOLD}  ❌ ALL TABLES ARE GONE${NC}"
    echo -e "${RED}  The database is completely empty.${NC}"
    echo -e "${RED}  $ANSWER_COUNT answer submissions — GONE${NC}"
    echo -e "${RED}  $STUDENT_COUNT student records — GONE${NC}"
    echo -e "${RED}  $COURSE_COUNT courses — GONE${NC}"
else
    echo -e "${RED}  Tables remaining: $TABLE_COUNT (data may be corrupted)${NC}"
fi

echo ""
echo -e "${YELLOW}This is exactly what happened in the real incident.${NC}"
echo -e "${YELLOW}1.9 million rows of student data from 2.5 years — gone in seconds.${NC}"
pause

# Summary
echo -e "${BOLD}📝 INCIDENT SUMMARY${NC}"
echo "==================="
echo ""
echo "Root causes:"
echo "  1. 🖥️  Terraform state was stored locally (not remote)"
echo "  2. 📂 Multiple projects shared the same infrastructure"
echo "  3. 🤖 AI agent was given permission to run destructive commands"
echo "  4. 🔓 No deletion protection on the database"
echo "  5. 💾 Automated backups were deleted WITH the database"
echo ""
echo "The recovery took 24 hours and required Azure Support escalation."
echo ""
echo -e "${GREEN}${BOLD}Next: Run 'make recover' to practice restoring from backup (Step 3)${NC}"
echo ""
