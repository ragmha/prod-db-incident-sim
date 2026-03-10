# =============================================================================
# "Production" Infrastructure — Azure
# =============================================================================
# This Terraform configuration represents a typical Azure production setup
# for a course management platform, similar to the real incident.
#
# IMPORTANT: These are EDUCATIONAL Terraform files. They demonstrate what
# real Azure infrastructure looks like. The actual simulation runs in Docker
# (PostgreSQL + Azurite), but these files show the real Azure equivalents.
#
# ⚠️ Notice what's MISSING:
#   - No resource locks (azurerm_management_lock)
#   - No lifecycle { prevent_destroy = true }
#   - No immutable backup vault
#   - State stored LOCALLY (not in Azure Blob Storage)
#   These gaps are exactly what made the real incident so devastating.
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # ⚠️ STATE IS LOCAL — ROOT CAUSE OF THE INCIDENT
  # On a new machine, this file won't exist.
  # Terraform will think NO infrastructure exists and try to create everything.
  # The fix: use backend "azurerm" with Azure Blob Storage (see guardrails/)
}

provider "azurerm" {
  features {}
  skip_provider_registration = true  # Educational example
}

# -----------------------------------------------------------------------------
# Resource Group — Container for all production resources
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Virtual Network — Private network for all resources
# Azure equivalent of AWS VPC
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name

  tags = azurerm_resource_group.production.tags
}

resource "azurerm_subnet" "database" {
  name                 = "database-subnet"
  resource_group_name  = azurerm_resource_group.production.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "postgresql-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "application" {
  name                 = "application-subnet"
  resource_group_name  = azurerm_resource_group.production.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "gateway-subnet"
  resource_group_name  = azurerm_resource_group.production.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}

# -----------------------------------------------------------------------------
# Azure Database for PostgreSQL Flexible Server
# This is the CRITICAL resource — 55K+ rows of student data
# Azure equivalent of AWS RDS
# -----------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server" "production" {
  name                   = "${var.project_name}-${var.environment}-psql"
  resource_group_name    = azurerm_resource_group.production.name
  location               = azurerm_resource_group.production.location
  version                = "16"
  delegated_subnet_id    = azurerm_subnet.database.id
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

resource "azurerm_postgresql_flexible_server_database" "course_platform" {
  name      = "course_platform"
  server_id = azurerm_postgresql_flexible_server.production.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# -----------------------------------------------------------------------------
# Azure Container Apps Environment — Runs the application
# Azure equivalent of AWS ECS
# -----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-logs"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = azurerm_resource_group.production.tags
}

resource "azurerm_container_app_environment" "production" {
  name                       = "${var.project_name}-${var.environment}-cae"
  location                   = azurerm_resource_group.production.location
  resource_group_name        = azurerm_resource_group.production.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = azurerm_resource_group.production.tags
}

# -----------------------------------------------------------------------------
# Application Gateway — Load balancer / traffic routing
# Azure equivalent of AWS ALB
# -----------------------------------------------------------------------------
resource "azurerm_public_ip" "gateway" {
  name                = "${var.project_name}-${var.environment}-pip"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = azurerm_resource_group.production.tags
}

# -----------------------------------------------------------------------------
# Storage Account — Application backups and artifacts
# Azure equivalent of AWS S3
# -----------------------------------------------------------------------------
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

resource "azurerm_storage_container" "backups" {
  name                  = "database-backups"
  storage_account_name  = azurerm_storage_account.backups.name
  container_access_type = "private"
}
