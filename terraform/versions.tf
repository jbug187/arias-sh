terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.50"
    }
  }

  # State lives in the private storage account created by bootstrap.ps1.
  # Auth: Azure CLI locally, OIDC in GitHub Actions (ARM_USE_OIDC). No keys.
  backend "azurerm" {
    resource_group_name  = "rg-arias-tfstate"
    storage_account_name = "ariasshtfstate"
    container_name       = "tfstate"
    key                  = "arias-sh.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  # Subscription comes from ARM_SUBSCRIPTION_ID (GitHub variable in CI, $env: locally).
  # The GitHub identity has no subscription-wide rights; providers were registered in Phase 0.
  resource_provider_registrations = "none"

  features {
    key_vault {
      # Purging/recovering soft-deleted vaults needs subscription-level rights we don't grant.
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = false
    }
  }
}
