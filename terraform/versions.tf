terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
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

# Helm talks to the cluster as whoever is signed in to Azure CLI (you locally, the OIDC identity in CI).
# kubelogin turns that sign-in into a Kubernetes token; no kubeconfig or cluster secret is stored.
provider "helm" {
  kubernetes = {
    host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      # 6dae42f8-... is the fixed Entra application ID of the AKS API server.
      args = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"]
    }
  }
}
