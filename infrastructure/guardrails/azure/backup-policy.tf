# ============================================================================
# Azure Backup — Immutable backups that survive resource deletion
#
# In the real incident, RDS automated snapshots were DELETED along with
# the database. Azure Backup with immutability policies prevents this.
#
# KEY DIFFERENCE:
# - AWS RDS automated snapshots are tied to the instance lifecycle.
#   Delete the instance → snapshots are deleted too (unless manually copied).
# - Azure Backup vault is INDEPENDENT of the source resource.
#   Delete the database → backups remain intact in the vault.
#
# This is the safety net that catches you when all other guardrails fail.
# ============================================================================

# -----------------------------------------------------------------------------
# Recovery Services Vault — The independent, protected backup store
#
# Think of this as a fireproof safe for your data. The vault exists
# independently of the resources it protects. Even if someone deletes
# the entire resource group containing the database, the vault (in a
# separate resource group) still has the backups.
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "backup" {
  name     = "rg-course-platform-backup"
  location = "East US"

  # IMPORTANT: This resource group is SEPARATE from the production one.
  # Separating backup infrastructure from production infrastructure means
  # a single `terraform destroy` on the production workspace cannot touch
  # the backups.
  tags = {
    environment = "production-backup"
    project     = "course-platform"
    purpose     = "disaster-recovery"
    criticality = "critical"
  }
}

resource "azurerm_recovery_services_vault" "production" {
  name                = "rsv-course-platform-prod"
  resource_group_name = azurerm_resource_group.backup.name
  location            = azurerm_resource_group.backup.location
  sku                 = "Standard"

  # ---------------------------------------------------------------------------
  # Soft Delete — The first layer of backup protection
  #
  # When soft delete is enabled, deleted backup data is retained for 14
  # additional days. This means even if someone intentionally deletes
  # a backup item, you have 14 days to recover it.
  # ---------------------------------------------------------------------------
  soft_delete_enabled = true

  tags = {
    environment = "production-backup"
    purpose     = "database-disaster-recovery"
  }
}

# -----------------------------------------------------------------------------
# Immutability Policy (via vault properties)
#
# Azure Recovery Services Vaults support immutability at the vault level.
# Once enabled, backup data CANNOT be deleted before its retention period
# expires — not by admins, not by scripts, not by Terraform, not by anyone.
#
# Even if someone deletes the database, these backups cannot be deleted.
#
# Three immutability states:
#   - Disabled:  No immutability (default, not recommended for production)
#   - Unlocked:  Immutability enabled, but can be disabled (good start)
#   - Locked:    Immutability enabled and IRREVERSIBLE (strongest protection)
#
# For production databases, use "Locked" — it guarantees recoverability.
# -----------------------------------------------------------------------------
resource "azurerm_recovery_services_vault" "immutable_vault" {
  name                = "rsv-course-platform-immutable"
  resource_group_name = azurerm_resource_group.backup.name
  location            = azurerm_resource_group.backup.location
  sku                 = "Standard"

  soft_delete_enabled = true

  # Immutability ensures backup data cannot be deleted early.
  # This is the Azure equivalent of "break glass" protection for backups.
  immutability = "Locked"

  tags = {
    environment = "production-backup"
    purpose     = "immutable-database-backups"
    warning     = "LOCKED-immutability-cannot-be-reversed"
  }
}

# -----------------------------------------------------------------------------
# Backup Policy for PostgreSQL — Defines retention schedule
#
# This policy controls:
# - How often backups are taken
# - How long each backup tier is retained
# - Which backups are promoted to weekly/monthly/yearly
# -----------------------------------------------------------------------------
resource "azurerm_backup_policy_vm" "database_backup_policy" {
  name                = "policy-database-daily-weekly"
  resource_group_name = azurerm_resource_group.backup.name
  recovery_vault_name = azurerm_recovery_services_vault.production.name

  timezone = "UTC"

  # ---------------------------------------------------------------------------
  # Daily Backup — Every day at 2:00 AM UTC
  #
  # This runs during the lowest-traffic window for the course platform.
  # Daily backups give us granular recovery points for recent incidents.
  # ---------------------------------------------------------------------------
  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  # ---------------------------------------------------------------------------
  # Daily Retention — Keep 30 days of daily backups
  #
  # If we discover the incident within 30 days (which we did — it was
  # immediate), we can restore to any point in the last month.
  # ---------------------------------------------------------------------------
  retention_daily {
    count = 30
  }

  # ---------------------------------------------------------------------------
  # Weekly Retention — Keep 12 weeks of weekly backups (every Sunday)
  #
  # For incidents discovered later, weekly snapshots provide a 3-month
  # recovery window with reasonable storage costs.
  # ---------------------------------------------------------------------------
  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  # ---------------------------------------------------------------------------
  # Monthly Retention — Keep 12 months of monthly backups
  #
  # Annual audit and compliance requirements often need monthly snapshots.
  # These are promoted from the first Sunday of each month.
  # ---------------------------------------------------------------------------
  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }

  # ---------------------------------------------------------------------------
  # Yearly Retention — Keep 3 years of yearly backups
  #
  # Long-term retention for regulatory compliance and historical data needs.
  # ---------------------------------------------------------------------------
  retention_yearly {
    count    = 3
    weekdays = ["Sunday"]
    weeks    = ["First"]
    months   = ["January"]
  }
}

# =============================================================================
# 📝 EDUCATIONAL NOTES
# =============================================================================
#
# HOW THIS WOULD HAVE PREVENTED THE INCIDENT:
#
# In the real incident, the chain of failure was:
#
#   1. `terraform destroy` runs
#   2. RDS instance is deleted
#   3. Automated snapshots are deleted WITH the instance  ← DISASTER
#   4. No independent backups exist
#   5. Data is permanently lost
#
# With Azure Backup configured as above:
#
#   1. `terraform destroy` runs
#   2. Resource lock blocks deletion (first guardrail)
#   3. Even IF the lock is bypassed and the database is deleted...
#   4. Backup vault STILL has all backup data (independent lifecycle)
#   5. Immutability policy prevents anyone from deleting the backups
#   6. Recovery is possible from any retention point
#   7. Data is safe. Crisis averted.
#
# COMPARISON: AWS vs Azure Backup Lifecycle
#
# | Scenario                    | AWS RDS Automated Snapshots       | Azure Backup Vault          |
# |-----------------------------|-----------------------------------|-----------------------------|
# | Database deleted             | Snapshots deleted too (!)         | Backups remain in vault     |
# | Manual snapshot exists       | Survives deletion                 | Survives deletion           |
# | Someone deletes the backups  | Gone immediately                  | Soft delete: 14-day grace   |
# | Immutability enabled         | Not available for RDS snapshots   | Cannot delete until expiry  |
# | Cross-region                 | Manual copy required              | Geo-redundant vault option  |
#
# THE KEY TAKEAWAY:
#
# Backups must be INDEPENDENT of the resources they protect.
# If deleting the resource also deletes the backup, it's not really a backup —
# it's just a copy that shares the same fate.
#
# =============================================================================
