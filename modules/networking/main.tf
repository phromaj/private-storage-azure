# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]

  tags = var.tags
}

# Network Security Groups
resource "azurerm_network_security_group" "main" {
  for_each = var.nsg_names

  name                = each.value
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Network Security Group Rules
resource "azurerm_network_security_rule" "main" {
  for_each = {
    for rule in flatten([
      for nsg_key, rules in var.nsg_rules : [
        for rule in rules : {
          key                        = "${nsg_key}-${rule.name}"
          nsg_key                    = nsg_key
          name                       = rule.name
          priority                   = rule.priority
          direction                  = rule.direction
          access                     = rule.access
          protocol                   = rule.protocol
          source_port_range          = rule.source_port_range
          destination_port_range     = rule.destination_port_range
          source_address_prefix      = rule.source_address_prefix
          destination_address_prefix = rule.destination_address_prefix
        }
      ]
    ]) : rule.key => rule
  }

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.main[each.value.nsg_key].name
}

# Subnets
resource "azurerm_subnet" "main" {
  for_each = var.subnet_configs

  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints
}

# Associate Network Security Groups with Subnets
resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = var.subnet_configs

  subnet_id                 = azurerm_subnet.main[each.key].id
  network_security_group_id = azurerm_network_security_group.main[each.key].id
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "main" {
  count = var.enable_private_dns_zone ? 1 : 0

  name                = var.private_dns_zone_name
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link Private DNS Zone to Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  count = var.enable_private_dns_zone ? 1 : 0

  name                  = "vnet-link-${var.vnet_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}
