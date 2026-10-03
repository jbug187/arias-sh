output "name_servers" {
  description = "Enter these four at Spaceship in Phase 3."
  value       = azurerm_dns_zone.main.name_servers
}

output "ingress_ip" {
  value = azurerm_public_ip.ingress.ip_address
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.main.oidc_issuer_url
}
