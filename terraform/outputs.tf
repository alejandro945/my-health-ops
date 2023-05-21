output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}

output "vmPrivateIp" {
  value = azurerm_network_interface.main.private_ip_address
}

output "vmPublicIp" {
  value = azurerm_public_ip.main.ip_address
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "acr_username" {
  value = azurerm_container_registry.main.admin_username
}

output "acr_password" {
  value = azurerm_container_registry.main.admin_password
  sensitive = true
}

