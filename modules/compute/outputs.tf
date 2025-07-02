# Virtual Machine Outputs
output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_windows_virtual_machine.main.name
}

output "vm_id" {
  description = "ID of the virtual machine"
  value       = azurerm_windows_virtual_machine.main.id
}

output "vm_private_ip" {
  description = "Private IP address of the virtual machine"
  value       = azurerm_network_interface.main.private_ip_address
}

output "vm_public_ip" {
  description = "Public IP address of the virtual machine"
  value       = var.enable_public_ip ? azurerm_public_ip.main[0].ip_address : null
}

output "vm_fqdn" {
  description = "FQDN of the virtual machine"
  value       = var.enable_public_ip ? azurerm_public_ip.main[0].fqdn : null
}

# Network Interface Outputs
output "network_interface_id" {
  description = "ID of the network interface"
  value       = azurerm_network_interface.main.id
}

output "network_interface_name" {
  description = "Name of the network interface"
  value       = azurerm_network_interface.main.name
}

# Public IP Outputs
output "public_ip_id" {
  description = "ID of the public IP"
  value       = var.enable_public_ip ? azurerm_public_ip.main[0].id : null
}

output "public_ip_address" {
  description = "Public IP address"
  value       = var.enable_public_ip ? azurerm_public_ip.main[0].ip_address : null
}

# Connection Information
output "rdp_connection_string" {
  description = "RDP connection string for the VM"
  value       = var.enable_public_ip ? "mstsc /v:${azurerm_public_ip.main[0].ip_address}" : "mstsc /v:${azurerm_network_interface.main.private_ip_address}"
}

output "admin_username" {
  description = "Administrator username for the VM"
  value       = var.admin_username
}
