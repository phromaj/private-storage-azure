variable "location" {
  description = "Azure region for networking resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
}

variable "subnet_configs" {
  description = "Configuration for subnets"
  type = map(object({
    name             = string
    address_prefixes = list(string)
    service_endpoints = list(string)
  }))
}

variable "private_dns_zone_name" {
  description = "Name of the private DNS zone"
  type        = string
}

variable "enable_private_dns_zone" {
  description = "Whether to create private DNS zone"
  type        = bool
  default     = true
}

variable "nsg_names" {
  description = "Names for network security groups"
  type = map(string)
}

variable "nsg_rules" {
  description = "Network security group rules"
  type = map(list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  })))
  default = {}
}

variable "tags" {
  description = "Tags to apply to networking resources"
  type        = map(string)
  default     = {}
}
