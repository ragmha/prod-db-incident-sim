output "resource_group_name" {
  description = "Name of the production resource group"
  value       = azurerm_resource_group.production.name
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.production.name
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "container_app_environment_name" {
  description = "Name of the Container Apps environment"
  value       = azurerm_container_app_environment.production.name
}

output "storage_account_name" {
  description = "Name of the backup storage account"
  value       = azurerm_storage_account.backups.name
}
