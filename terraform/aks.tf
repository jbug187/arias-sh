resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-arias-sh"
  location            = local.location
  resource_group_name = local.rg
  dns_prefix          = "arias-sh"
  sku_tier            = "Free"
  tags                = local.tags

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # Entra ID sign-in + Azure RBAC for kubectl; no static admin credentials exist.
  local_account_disabled = true
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  # Needed in Phase 4 so External Secrets can read Key Vault without a secret.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_vm_size
    node_count                  = 1
    os_disk_size_gb             = 30
    vnet_subnet_id              = azurerm_subnet.aks.id
    temporary_name_for_rotation = "systemtmp"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "10.20.0.0/16"
    dns_service_ip      = "10.20.0.10"
  }

  identity {
    type = "SystemAssigned"
  }
}

# The cluster manages the subnet and attaches the static IP, both of which live in our resource group.
resource "azurerm_role_assignment" "aks_network" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

# kubectl access: John and the GitHub Actions identity.
resource "azurerm_role_assignment" "aks_admin" {
  for_each = {
    admin    = var.admin_object_id
    deployer = var.deployer_object_id
  }

  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}
