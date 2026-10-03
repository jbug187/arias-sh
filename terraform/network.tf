resource "azurerm_virtual_network" "main" {
  name                = "vnet-arias-sh"
  location            = local.location
  resource_group_name = local.rg
  address_space       = ["10.10.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = local.rg
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Fixed ingress address. Traefik's LoadBalancer service will claim it in Phase 4.
resource "azurerm_public_ip" "ingress" {
  name                = "pip-arias-ingress"
  location            = local.location
  resource_group_name = local.rg
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}
