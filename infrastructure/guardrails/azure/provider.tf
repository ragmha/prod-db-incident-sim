# =============================================================================
# Azure Guardrails — Shared Provider Configuration
# =============================================================================
#
# ⚠️ EDUCATIONAL EXAMPLE ONLY
#
# These Terraform files demonstrate Azure guardrails that would have
# prevented the production database incident. They are NOT meant to be
# run against a real Azure subscription from this exercise.
#
# The provider is configured with skip_provider_registration = true
# so that `terraform validate` can check syntax without Azure credentials.
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  skip_provider_registration = true
}
