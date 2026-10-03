# The resource group already exists (bootstrap.ps1); the pipeline identity is scoped to it.
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

locals {
  location = data.azurerm_resource_group.main.location
  rg       = data.azurerm_resource_group.main.name
  tags     = { project = "arias-sh", managed_by = "terraform" }
}
