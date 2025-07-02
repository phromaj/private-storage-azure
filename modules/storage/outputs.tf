# Storage Account Outputs
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_account_primary_access_key" {
  description = "Primary access key of the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "storage_account_primary_connection_string" {
  description = "Primary connection string of the storage account"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

# Private Endpoint Outputs
output "private_endpoint_ids" {
  description = "Map of private endpoint names to their IDs"
  value = {
    for key, pe in azurerm_private_endpoint.main : key => pe.id
  }
}

output "private_endpoint_names" {
  description = "Map of private endpoint types to their names"
  value = {
    for key, pe in azurerm_private_endpoint.main : key => pe.name
  }
}

output "private_endpoint_ip_addresses" {
  description = "Map of private endpoint names to their IP addresses"
  value = {
    for key, pe in azurerm_private_endpoint.main : key => pe.private_service_connection[0].private_ip_address
  }
}

# Primary blob private endpoint outputs (for convenience)
output "private_endpoint_name" {
  description = "Name of the primary blob private endpoint"
  value       = contains(keys(azurerm_private_endpoint.main), "blob") ? azurerm_private_endpoint.main["blob"].name : null
}

output "private_endpoint_id" {
  description = "ID of the primary blob private endpoint"
  value       = contains(keys(azurerm_private_endpoint.main), "blob") ? azurerm_private_endpoint.main["blob"].id : null
}

output "private_endpoint_ip_address" {
  description = "IP address of the primary blob private endpoint"
  value       = contains(keys(azurerm_private_endpoint.main), "blob") ? azurerm_private_endpoint.main["blob"].private_service_connection[0].private_ip_address : null
}

output "private_endpoint_fqdn" {
  description = "FQDN that resolves to the private endpoint"
  value       = "${azurerm_storage_account.main.name}.blob.core.windows.net"
}

# Storage Container Outputs
output "example_container_name" {
  description = "Name of the example container"
  value       = length(azurerm_storage_container.example) > 0 ? azurerm_storage_container.example[0].name : null
}

output "example_container_id" {
  description = "ID of the example container"
  value       = length(azurerm_storage_container.example) > 0 ? azurerm_storage_container.example[0].id : null
}
