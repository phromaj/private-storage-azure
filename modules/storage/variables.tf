variable "location" {
  description = "Azure region for storage resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "storage_config" {
  description = "Storage account configuration"
  type = object({
    name                              = string
    account_tier                      = string
    account_replication_type          = string
    account_kind                      = string
    access_tier                       = string
    allow_nested_items_to_be_public   = bool
    shared_access_key_enabled         = bool
    public_network_access_enabled     = bool
    https_traffic_only_enabled        = bool
    min_tls_version                   = string
    blob_properties = object({
      versioning_enabled       = bool
      delete_retention_policy = object({
        days = number
      })
      container_delete_retention_policy = object({
        days = number
      })
    })
  })
}

variable "private_endpoints" {
  description = "Private endpoints configuration"
  type = map(object({
    subresource_names = list(string)
    private_dns_zone  = string
  }))
}

variable "subnet_id" {
  description = "ID of the subnet for private endpoints"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Map of private DNS zone names to their IDs"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to storage resources"
  type        = map(string)
  default     = {}
}
