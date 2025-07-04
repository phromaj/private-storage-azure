# Resource Group Information
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.main.id
}

output "location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.main.location
}

# Networking Outputs
output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.networking.vnet_name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = module.networking.vnet_address_space
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value       = module.networking.subnet_ids
}

output "subnet_names" {
  description = "Map of subnet types to their names"
  value       = module.networking.subnet_names
}

output "private_dns_zone_name" {
  description = "Name of the private DNS zone"
  value       = var.enable_private_dns_zone ? module.networking.private_dns_zone_name : null
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone"
  value       = var.enable_private_dns_zone ? module.networking.private_dns_zone_id : null
}

# Storage Outputs
output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage.storage_account_name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = module.storage.storage_account_id
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = module.storage.storage_account_primary_blob_endpoint
}

output "storage_account_private_endpoint_ip" {
  description = "Private IP address of the storage account private endpoint"
  value       = module.storage.private_endpoint_ip_address
}

output "private_endpoint_fqdn" {
  description = "FQDN that resolves to the private endpoint"
  value       = module.storage.private_endpoint_fqdn
}

# Private Endpoint Information
output "private_endpoint_name" {
  description = "Name of the private endpoint"
  value       = module.storage.private_endpoint_name
}

output "private_endpoint_id" {
  description = "ID of the private endpoint"
  value       = module.storage.private_endpoint_id
}

# Virtual Machine Outputs (if created)
output "vm_name" {
  description = "Name of the test virtual machine"
  value       = var.create_test_vm ? module.compute[0].vm_name : null
}

output "vm_id" {
  description = "ID of the test virtual machine"
  value       = var.create_test_vm ? module.compute[0].vm_id : null
}

output "vm_private_ip" {
  description = "Private IP address of the test virtual machine"
  value       = var.create_test_vm ? module.compute[0].vm_private_ip : null
}

output "vm_public_ip" {
  description = "Public IP address of the test virtual machine"
  value       = var.create_test_vm ? module.compute[0].vm_public_ip : null
}

output "vm_fqdn" {
  description = "FQDN of the test virtual machine"
  value       = var.create_test_vm ? module.compute[0].vm_fqdn : null
}

# Monitoring Outputs (if enabled)
output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = var.create_monitoring ? module.monitoring[0].log_analytics_workspace_name : null
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.create_monitoring ? module.monitoring[0].log_analytics_workspace_id : null
}

output "action_group_id" {
  description = "ID of the monitoring action group"
  value       = var.create_monitoring ? module.monitoring[0].action_group_id : null
}

output "data_collection_endpoint_id" {
  description = "ID of the data collection endpoint"
  value       = var.create_monitoring && var.enable_advanced_monitoring ? module.monitoring[0].data_collection_endpoint_id : null
}

output "data_collection_rule_id" {
  description = "ID of the data collection rule"
  value       = var.create_monitoring && var.enable_advanced_monitoring ? module.monitoring[0].data_collection_rule_id : null
}

# Connection Information
output "connection_test_commands" {
  description = "Commands to test the private endpoint connectivity"
  value = {
    dns_resolution = "nslookup ${module.storage.storage_account_name}.blob.core.windows.net"
    connectivity   = "Test-NetConnection ${module.storage.storage_account_name}.blob.core.windows.net -Port 443"
    expected_ip    = "Should resolve to IP in range ${var.subnet_address_prefixes.private_endpoints}"
  }
}

# Security Information
output "security_summary" {
  description = "Summary of security configurations"
  value = {
    public_access_disabled    = "Storage account public access is disabled"
    private_endpoint_enabled  = "Private endpoint is configured for blob storage"
    https_only                = "HTTPS-only traffic is enforced"
    minimum_tls_version       = "Minimum TLS version is 1.2"
    network_access_restricted = "Access is restricted to private network only"
  }
}

# Resource Tags
output "tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}

# Quick Reference
output "quick_reference" {
  description = "Quick reference for common tasks"
  value = {
    rdp_to_vm = var.create_test_vm && var.enable_rdp_access ? "RDP to ${module.compute[0].vm_public_ip != null ? module.compute[0].vm_public_ip : module.compute[0].vm_private_ip} with username: ${var.admin_username}" : "RDP access not enabled or VM not created"

    storage_access = "Storage can only be accessed from within the VNet via private endpoint at ${module.storage.private_endpoint_ip_address}"

    dns_zone = var.enable_private_dns_zone ? "Private DNS zone ${module.networking.private_dns_zone_name} handles name resolution" : "Private DNS zone not configured"
  }
}
