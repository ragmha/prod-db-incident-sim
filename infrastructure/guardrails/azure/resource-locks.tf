# ============================================================================
# Azure Resource Locks — The guardrail that would have saved the database
#
# In the real incident, `terraform destroy` deleted the production database
# because there was NOTHING preventing it. Azure Resource Locks add that
# critical friction layer.
#
# Two types of locks:
# - CanNotDelete: Prevents deletion but allows modifications
# - ReadOnly: Prevents both deletion AND modifications
#
# KEY INSIGHT: Resource locks apply at the Azure Resource Manager (ARM) level,
# OUTSIDE of Terraform's control. Even if Terraform plans a destroy, Azure
# itself refuses to execute it.
# ============================================================================

# Provider configuration is in provider.tf (shared across all azure guardrail files)

# -----------------------------------------------------------------------------
# Resource Group — The container for all production resources
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "production" {
  name     = "rg-course-platform-production"
  location = "East US"

  tags = {
    environment = "production"
    project     = "course-platform"
    managed_by  = "terraform"
    criticality = "high"
  }
}

# -----------------------------------------------------------------------------
# PostgreSQL Flexible Server — The production database
#
# This is the Azure equivalent of the AWS RDS PostgreSQL instance that was
# destroyed in the real incident.
# -----------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server" "production" {
  name                = "psql-course-platform-prod"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location

  administrator_login    = "courseplatformadmin"
  administrator_password = var.db_admin_password

  sku_name   = "GP_Standard_D4s_v3"
  version    = "15"
  storage_mb = 131072 # 128 GB

  zone = "1"

  backup_retention_days        = 35 # Maximum retention
  geo_redundant_backup_enabled = true

  tags = {
    environment = "production"
    data_class  = "confidential"
  }
}

variable "db_admin_password" {
  description = "Administrator password for the PostgreSQL server"
  type        = string
  sensitive   = true
  default     = "CHANGE-ME-in-real-deployment" # Placeholder for demonstration
}

# =============================================================================
#  🔒 RESOURCE LOCKS — The critical guardrail
# =============================================================================

# -----------------------------------------------------------------------------
# Lock #1: CanNotDelete lock on the production database
#
# Even if an AI agent or human runs `terraform destroy`, the lock blocks it.
#
# What happens when someone tries to delete this resource:
#
#   Error: deleting PostgreSQL Flexible Server "psql-course-platform-prod":
#   ScopeLocked - The scope '/subscriptions/.../psql-course-platform-prod'
#   cannot perform delete operation because following scope(s) are locked:
#   '/subscriptions/.../psql-course-platform-prod/providers/
#   Microsoft.Authorization/locks/lock-production-database-nodelete'.
#   Please remove the lock and try again.
#
# That error message IS the guardrail working. The destroy is blocked at
# the Azure API level — Terraform never even gets the chance to delete it.
# -----------------------------------------------------------------------------
resource "azurerm_management_lock" "database_no_delete" {
  name       = "lock-production-database-nodelete"
  scope      = azurerm_postgresql_flexible_server.production.id
  lock_level = "CanNotDelete"
  notes      = "PRODUCTION DATABASE — Cannot be deleted without explicit lock removal. This lock exists because of the Q3 production database incident."
}

# -----------------------------------------------------------------------------
# Lock #2: CanNotDelete lock on the resource group
#
# This is a SECOND layer of protection. Even if someone removes the database
# lock, the resource group lock still prevents deletion of anything inside it.
#
# Think of it as defense in depth:
#   Layer 1: Database-level lock → blocks direct database deletion
#   Layer 2: Resource group lock → blocks deletion of the entire group
#
# To actually destroy the database, an operator would need to:
#   1. Remove the database lock       (deliberate action #1)
#   2. Remove the resource group lock  (deliberate action #2)
#   3. Run terraform destroy           (deliberate action #3)
#
# Three deliberate steps vs. one accidental command. That friction saves data.
# -----------------------------------------------------------------------------
resource "azurerm_management_lock" "resource_group_no_delete" {
  name       = "lock-production-rg-nodelete"
  scope      = azurerm_resource_group.production.id
  lock_level = "CanNotDelete"
  notes      = "PRODUCTION RESOURCE GROUP — All resources in this group are protected from accidental deletion."
}

# =============================================================================
# 📝 EDUCATIONAL NOTES
# =============================================================================
#
# WHY THIS MATTERS:
#
# In the real incident, the production database was deleted by a single
# `terraform destroy` command. There was zero friction between "run command"
# and "database gone forever."
#
# Azure Resource Locks add exactly the kind of friction that prevents
# accidents while still allowing intentional, well-considered changes.
#
# AZURE RESOURCE LOCK CAPABILITIES:
#
# | Feature                    | Azure Management Lock                          |
# |----------------------------|------------------------------------------------|
# | Deletion protection        | CanNotDelete lock on any resource               |
# | Modification protection    | ReadOnly lock prevents all changes              |
# | Scope                      | Any scope — resource, resource group, or sub    |
# | Blocks Terraform destroy?  | Yes — enforced at the ARM API level             |
# | Independent of Terraform?  | Fully — ARM-level enforcement                   |
# | Can protect entire groups? | Yes — resource group locks protect all children  |
#
# IMPORTANT CAVEAT:
#
# Locks are managed in Terraform here, which means `terraform destroy` would
# try to remove the lock first, then the resource. In a real production setup,
# you might want to create locks OUTSIDE of Terraform (via Azure CLI or Portal)
# so that Terraform cannot manage them at all:
#
#   az lock create --name lock-production-db \
#     --lock-type CanNotDelete \
#     --resource-group rg-course-platform-production \
#     --resource-name psql-course-platform-prod \
#     --resource-type Microsoft.DBforPostgreSQL/flexibleServers \
#     --notes "Created outside Terraform — immune to terraform destroy"
#
# =============================================================================
