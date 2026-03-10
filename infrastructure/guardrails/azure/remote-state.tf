# ============================================================================
# Remote State in Azure Blob Storage — Prevents the "new laptop" problem
#
# ROOT CAUSE of the incident: Terraform state was stored LOCALLY.
# When the engineer switched to a new computer, the state file was missing.
# Terraform thought no infrastructure existed and tried to create everything.
#
# Azure Blob Storage with lease-based locking solves this completely.
#
# This file demonstrates:
#   (a) How to configure remote state with Azure Blob Storage
#   (b) How lease-based locking prevents concurrent modifications
#   (c) How blob versioning prevents state file corruption
# ============================================================================

# -----------------------------------------------------------------------------
# Backend Configuration (Commented Out)
#
# This block MUST be commented out because:
# - Terraform backends cannot use variables or expressions
# - Backend configuration is processed before any other Terraform operations
# - This file is for educational demonstration within the exercise
#
# In a REAL deployment, this block would be uncommented and configured with
# actual Azure storage account details.
# -----------------------------------------------------------------------------

# terraform {
#   backend "azurerm" {
#     # -----------------------------------------------------------------------
#     # Storage Account Details
#     #
#     # The storage account that holds the state file. This should be in a
#     # SEPARATE resource group from the infrastructure it manages — so that
#     # destroying the infrastructure cannot destroy the state.
#     # -----------------------------------------------------------------------
#     resource_group_name  = "rg-terraform-state"
#     storage_account_name = "stcourseplatformtfstate"
#     container_name       = "tfstate"
#     key                  = "course-platform/production/terraform.tfstate"
#
#     # -----------------------------------------------------------------------
#     # Lease-Based State Locking
#     #
#     # Azure Blob Storage uses blob leases for state locking. When Terraform
#     # starts an operation (plan, apply, destroy), it acquires a lease on the
#     # state blob. If another process tries to run Terraform concurrently,
#     # it sees the lease and WAITS or FAILS — preventing state corruption.
#     #
#     # This is enabled by default with the azurerm backend. No extra config
#     # needed. It just works.
#     # -----------------------------------------------------------------------
#
#     # -----------------------------------------------------------------------
#     # Authentication
#     #
#     # Multiple auth methods available. For CI/CD, use service principal or
#     # managed identity. NEVER store credentials in this file.
#     # -----------------------------------------------------------------------
#     # use_oidc = true  # Recommended for GitHub Actions
#     # use_msi  = true  # Recommended for Azure-hosted CI/CD
#   }
# }

# =============================================================================
# Infrastructure for Remote State Storage
#
# These resources CREATE the storage account that holds the Terraform state.
# In practice, this would be provisioned ONCE by a platform team, BEFORE
# any application infrastructure is deployed.
#
# CHICKEN-AND-EGG NOTE: This state storage infrastructure is typically
# created manually or with a separate bootstrap script, since you can't
# use remote state to store the state of the remote state infrastructure.
# =============================================================================

# -----------------------------------------------------------------------------
# Dedicated Resource Group for Terraform State
#
# Keeping state storage in its own resource group means:
# - Application team destroy operations can't touch it
# - Separate RBAC permissions can be applied
# - It's crystal clear what this resource group is for
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "terraform_state" {
  name     = "rg-terraform-state"
  location = "East US"

  tags = {
    environment = "shared-infrastructure"
    purpose     = "terraform-state-storage"
    managed_by  = "platform-team"
    criticality = "critical"
  }
}

# -----------------------------------------------------------------------------
# Storage Account — Where the state file lives
#
# Key configuration choices:
# - account_replication_type = "GRS" (Geo-Redundant Storage)
#   The state file is replicated to a paired Azure region. Even if an entire
#   region goes down, the state is safe.
#
# - blob_properties.versioning_enabled = true
#   Every change to the state file creates a new version. If state gets
#   corrupted, you can roll back to any previous version.
# -----------------------------------------------------------------------------
resource "azurerm_storage_account" "terraform_state" {
  name                     = "stcourseplatformtfstate"
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  min_tls_version          = "TLS1_2"

  # ---------------------------------------------------------------------------
  # Blob Versioning — Protection against state corruption
  #
  # Every time Terraform writes the state file, Azure keeps the previous
  # version. If a Terraform operation goes wrong and corrupts state, you
  # can restore a previous version from the Azure Portal or CLI:
  #
  #   az storage blob list --account-name stcourseplatformtfstate \
  #     --container-name tfstate \
  #     --include v \
  #     --prefix "course-platform/production/terraform.tfstate"
  #
  # This is like having automatic "undo" for your state file.
  # ---------------------------------------------------------------------------
  blob_properties {
    versioning_enabled = true

    # Keep deleted blobs recoverable for 30 days
    delete_retention_policy {
      days = 30
    }

    # Keep old versions for 90 days
    container_delete_retention_policy {
      days = 90
    }
  }

  tags = {
    environment = "shared-infrastructure"
    purpose     = "terraform-state-storage"
  }
}

# -----------------------------------------------------------------------------
# Storage Container — The "folder" for state files
#
# Each environment or project gets its own key (path) within this container.
# For example:
#   - course-platform/production/terraform.tfstate
#   - course-platform/staging/terraform.tfstate
#   - course-platform/dev/terraform.tfstate
# -----------------------------------------------------------------------------
resource "azurerm_storage_container" "terraform_state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private" # No anonymous access — ever

  # ---------------------------------------------------------------------------
  # Lease-Based State Locking — How it works under the hood
  #
  # When you run `terraform plan` or `terraform apply`:
  #
  #   1. Terraform calls Azure Blob Storage to acquire a LEASE on the state blob
  #   2. The lease is an exclusive lock — only one holder at a time
  #   3. If another `terraform apply` tries to run concurrently, it sees:
  #
  #        Error: Error acquiring the state lock
  #        Lock Info:
  #          ID:        a1b2c3d4-e5f6-...
  #          Path:      course-platform/production/terraform.tfstate
  #          Operation: OperationTypeApply
  #          Who:       engineer@company.com
  #          Created:   2024-01-15 14:30:00 UTC
  #
  #   4. After the operation completes, the lease is released
  #   5. If Terraform crashes, the lease expires after 60 seconds
  #
  # This prevents the scenario where two engineers (or an engineer and an AI
  # agent) run Terraform at the same time and create a split-brain state.
  # ---------------------------------------------------------------------------
}

# -----------------------------------------------------------------------------
# Lock on the State Storage — Protect the protector
#
# The state storage itself gets a resource lock. If someone accidentally
# deletes the storage account, ALL Terraform state for ALL environments
# would be lost. That would be even worse than losing one database.
# -----------------------------------------------------------------------------
resource "azurerm_management_lock" "state_storage_lock" {
  name       = "lock-terraform-state-nodelete"
  scope      = azurerm_storage_account.terraform_state.id
  lock_level = "CanNotDelete"
  notes      = "CRITICAL: This storage account contains Terraform state for all environments. Deletion would be catastrophic."
}

# =============================================================================
# 📝 EDUCATIONAL NOTES
# =============================================================================
#
# HOW REMOTE STATE PREVENTS THE INCIDENT:
#
# The incident happened because of this chain:
#
#   1. Engineer works on laptop A → state stored locally
#   2. Engineer gets new laptop B → state file not copied
#   3. Terraform on laptop B has EMPTY state
#   4. Terraform thinks nothing exists → plans to CREATE everything
#   5. CREATE fails for some resources (already exist)
#   6. Engineer runs `terraform destroy` to "clean up"
#   7. Destroy SUCCEEDS → production database deleted
#
# With remote state in Azure Blob Storage:
#
#   1. Engineer works on laptop A → state stored in Azure Blob Storage
#   2. Engineer gets new laptop B → runs `terraform init`
#   3. Terraform downloads state from Azure Blob Storage ← THE FIX
#   4. Terraform sees all existing infrastructure
#   5. `terraform plan` shows "No changes" ← CORRECT
#   6. No accidental destroy. Crisis averted.
#
# THREE PROBLEMS SOLVED:
#
# (a) STATE LOSS ON MACHINE SWITCH
#     Local state lives on one machine. Remote state lives in the cloud.
#     Any authorized machine can access it after `terraform init`.
#
# (b) CONCURRENT STATE MODIFICATIONS
#     Lease-based locking prevents two operators from running Terraform
#     at the same time. Without this, concurrent operations can corrupt
#     state or create conflicting infrastructure.
#
# (c) STATE FILE CORRUPTION
#     Blob versioning keeps every previous version of the state file.
#     If something goes wrong, you can restore a known-good state in
#     minutes, not hours.
#
# COMPARISON: Local State vs Azure Remote State
#
# | Problem                | Local State              | Azure Remote State            |
# |------------------------|--------------------------|-------------------------------|
# | New laptop             | State lost entirely      | `terraform init` restores it  |
# | Two engineers at once  | State corruption         | Lease lock prevents conflict  |
# | Accidental deletion    | rm terraform.tfstate     | Soft delete + versioning      |
# | Disk failure           | State gone               | GRS: replicated across regions|
# | Audit trail            | None                     | Blob versioning history       |
#
# =============================================================================
