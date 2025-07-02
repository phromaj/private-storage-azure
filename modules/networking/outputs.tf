# Virtual Network Outputs
output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.main.address_space
}

# Subnet Outputs
output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = {
    for key, subnet in azurerm_subnet.main : key => subnet.id
  }
}

output "subnet_names" {
  description = "Map of subnet types to their names"
  value = {
    for key, subnet in azurerm_subnet.main : key => subnet.name
  }
}

output "subnet_address_prefixes" {
  description = "Map of subnet names to their address prefixes"
  value = {
    for key, subnet in azurerm_subnet.main : key => subnet.address_prefixes
  }
}

# Network Security Group Outputs
output "nsg_ids" {
  description = "Map of NSG names to their IDs"
  value = {
    for key, nsg in azurerm_network_security_group.main : key => nsg.id
  }
}

output "nsg_names" {
  description = "Map of NSG types to their names"
  value = {
    for key, nsg in azurerm_network_security_group.main : key => nsg.name
  }
}

# Private DNS Zone Outputs
output "private_dns_zone_name" {
  description = "Name of the private DNS zone"
  value       = var.enable_private_dns_zone ? azurerm_private_dns_zone.main[0].name : null
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone"
  value       = var.enable_private_dns_zone ? azurerm_private_dns_zone.main[0].id : null
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone names to their IDs (for compatibility)"
  value = var.enable_private_dns_zone ? {
    (azurerm_private_dns_zone.main[0].name) = azurerm_private_dns_zone.main[0].id
  } : {}
}

# Virtual Network Link Output
output "private_dns_zone_vnet_link_id" {
  description = "ID of the private DNS zone virtual network link"
  value       = var.enable_private_dns_zone ? azurerm_private_dns_zone_virtual_network_link.main[0].id : null
}
