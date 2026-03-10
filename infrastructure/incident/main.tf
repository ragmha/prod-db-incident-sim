# =============================================================================
# ⚠️ INCIDENT SIMULATION — "The New Laptop"
# =============================================================================
# This is IDENTICAL to the production Terraform config, but notice:
# there is NO terraform.tfstate file in this directory!
#
# When you run `terraform plan` here, Terraform sees NO existing state
# and believes NOTHING exists. It will plan to CREATE everything fresh.
#
# This is exactly what happened in the real incident:
# - Engineer switched to a new computer
# - State file was on the old machine
# - Terraform planned to create duplicate resources
#
# In Azure terms, Terraform would try to create:
#   + azurerm_resource_group.production
#   + azurerm_virtual_network.main
#   + azurerm_postgresql_flexible_server.production  ← THE DATABASE
#   + azurerm_container_app_environment.production
#   + azurerm_storage_account.backups
#   ... and more
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # NOTE: State is stored LOCALLY — this is the root cause of the incident!
  # In a real setup, this should be remote (Azure Blob Storage backend)
  #
  # ⚠️ There is NO terraform.tfstate file here.
  # Terraform will believe nothing exists and plan to create everything.
}

provider "azurerm" {
  features {}
  skip_provider_registration = true  # Educational example
}

# =============================================================================
# Resources identical to ../production/main.tf
# See that file for the full configuration (resource group, virtual network,
# subnets, PostgreSQL, Container Apps, Application Gateway, storage).
#
# Below are the 3 KEY resources that demonstrate the incident:
# =============================================================================

# =============================================================================
# Resource Group — Container for all production resources
# =============================================================================
# Without state, Terraform will plan: + azurerm_resource_group.production (CREATE)
# In reality, this resource group already exists in Azure.

resource "azurerm_resource_group" "production" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.azure_region

  tags = {
    environment = var.environment
    project     = var.project_name
    managed_by  = "terraform"
  }

  # ⚠️ NO LOCK — Anyone with access can delete this resource group
  # and everything inside it, including the database.
}

# =============================================================================
# PostgreSQL Flexible Server — The database (the heart of the incident)
# =============================================================================
# Without state, Terraform will plan:
#   + azurerm_postgresql_flexible_server.production (CREATE)
# A DUPLICATE database would be created alongside the real one.
#
# ⚠️ CRITICAL: No deletion protection, no prevent_destroy lifecycle rule.
# This is what allowed `terraform destroy` to wipe 1.9 million rows.

resource "azurerm_postgresql_flexible_server" "production" {
  name                   = "${var.project_name}-${var.environment}-psql"
  resource_group_name    = azurerm_resource_group.production.name
  location               = azurerm_resource_group.production.location
  version                = "16"
  administrator_login    = "adminuser"
  administrator_password = var.db_password
  zone                   = "1"

  storage_mb = 32768
  sku_name   = "B_Standard_B1ms"

  # ⚠️ NO deletion_protection equivalent configured
  # ⚠️ NO lifecycle { prevent_destroy = true }
  # A single `terraform destroy` will wipe this database and all its data.

  tags = azurerm_resource_group.production.tags
}

# =============================================================================
# Storage Account — Application backups and artifacts
# =============================================================================
# Without state, Terraform will plan: + azurerm_storage_account.backups (CREATE)
# The automated backups stored here were also destroyed in the incident.

resource "azurerm_storage_account" "backups" {
  name                     = "${replace(var.project_name, "-", "")}${var.environment}bak"
  resource_group_name      = azurerm_resource_group.production.name
  location                 = azurerm_resource_group.production.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # ⚠️ No versioning enabled — deleted files are gone forever
  # ⚠️ No soft delete — no recovery window

  tags = azurerm_resource_group.production.tags
}
