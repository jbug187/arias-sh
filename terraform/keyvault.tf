resource "azurerm_key_vault" "main" {
  # Vault names are globally unique; a slice of the subscription ID keeps ours distinct.
  name                       = "kv-arias-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}"
  location                   = local.location
  resource_group_name        = local.rg
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}

# John can create and rotate secret values (Phase 7). Terraform never sees them.
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.admin_object_id
}

# The rotation workflow (Phase 8) writes new secret versions.
resource "azurerm_role_assignment" "kv_deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployer_object_id
}
