# =============================================================================
# EXAMPLE OUTPUTS
# =============================================================================

# Resource Group Information
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = module.private_storage_infrastructure.resource_group_name
}

output "location" {
  description = "Azure region where resources are deployed"
  value       = module.private_storage_infrastructure.location
}

# Networking Information
output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.private_storage_infrastructure.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value       = module.private_storage_infrastructure.subnet_ids
}

# Storage Information
output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.private_storage_infrastructure.storage_account_name
}

output "storage_account_private_endpoint_ip" {
  description = "Private IP address of the storage account private endpoint"
  value       = module.private_storage_infrastructure.storage_account_private_endpoint_ip
}

output "private_endpoint_fqdn" {
  description = "FQDN that resolves to the private endpoint"
  value       = module.private_storage_infrastructure.private_endpoint_fqdn
}

# Virtual Machine Information
output "vm_name" {
  description = "Name of the test virtual machine"
  value       = module.private_storage_infrastructure.vm_name
}

output "vm_public_ip" {
  description = "Public IP address of the test virtual machine"
  value       = module.private_storage_infrastructure.vm_public_ip
}

output "vm_private_ip" {
  description = "Private IP address of the test virtual machine"
  value       = module.private_storage_infrastructure.vm_private_ip
}

# Connection and Testing Information
output "connection_test_commands" {
  description = "Commands to test the private endpoint connectivity"
  value       = module.private_storage_infrastructure.connection_test_commands
}

output "security_summary" {
  description = "Summary of security configurations"
  value       = module.private_storage_infrastructure.security_summary
}

output "quick_reference" {
  description = "Quick reference for common tasks"
  value       = module.private_storage_infrastructure.quick_reference
}

# Example-specific outputs
output "deployment_summary" {
  description = "Summary of the complete deployment"
  value = {
    infrastructure_type = "Azure Private Storage with Private Endpoints"
    deployment_method   = "Terraform (Complete Example)"
    security_level      = "High - No public storage access"
    monitoring_enabled  = var.enable_monitoring
    test_vm_created     = var.create_test_vm
    bastion_enabled     = var.create_bastion
    environment         = var.environment
    estimated_cost      = "Low - Optimized for testing and POC"
  }
}

output "next_steps" {
  description = "Recommended next steps after deployment"
  value = {
    step_1 = "Connect to the test VM using RDP: ${module.private_storage_infrastructure.vm_public_ip != null ? module.private_storage_infrastructure.vm_public_ip : "Use private IP or Bastion"}"
    step_2 = "Test DNS resolution: nslookup ${module.private_storage_infrastructure.storage_account_name}.blob.core.windows.net"
    step_3 = "Test storage connectivity: Test-NetConnection ${module.private_storage_infrastructure.storage_account_name}.blob.core.windows.net -Port 443"
    step_4 = "Verify private endpoint IP is in range: ${var.subnet_address_prefixes.private_endpoints}"
    step_5 = "Test from external network (should fail): curl https://${module.private_storage_infrastructure.storage_account_name}.blob.core.windows.net"
    step_6 = "Review monitoring data in Log Analytics workspace (if enabled)"
  }
}
