resource "azurerm_dns_zone" "main" {
  name                = var.domain
  resource_group_name = local.rg
  tags                = local.tags
}

# Alias A records point at the public IP resource itself, so they follow it if it ever changes.
resource "azurerm_dns_a_record" "hosts" {
  for_each = toset(["@", "john", "stats"])

  name                = each.key
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = local.rg
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.ingress.id
}
