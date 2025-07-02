# Storage Account
resource "azurerm_storage_account" "main" {
  name                = var.storage_config.name
  resource_group_name = var.resource_group_name
  location            = var.location
  
  # Performance and redundancy
  account_tier             = var.storage_config.account_tier
  account_replication_type = var.storage_config.account_replication_type
  account_kind             = var.storage_config.account_kind
  access_tier              = var.storage_config.access_tier
  
  # Security settings
  allow_nested_items_to_be_public = var.storage_config.allow_nested_items_to_be_public
  shared_access_key_enabled       = var.storage_config.shared_access_key_enabled
  public_network_access_enabled   = var.storage_config.public_network_access_enabled
  
  # HTTPS and TLS enforcement
  https_traffic_only_enabled = var.storage_config.https_traffic_only_enabled
  min_tls_version           = var.storage_config.min_tls_version
  
  # Blob properties
  blob_properties {
    versioning_enabled = var.storage_config.blob_properties.versioning_enabled
    
    delete_retention_policy {
      days = var.storage_config.blob_properties.delete_retention_policy.days
    }
    
    container_delete_retention_policy {
      days = var.storage_config.blob_properties.container_delete_retention_policy.days
    }
  }
  
  tags = var.tags
}

# Private Endpoints
resource "azurerm_private_endpoint" "main" {
  for_each = var.private_endpoints
  
  name                = "pep-${var.storage_config.name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  
  private_service_connection {
    name                           = "psc-${var.storage_config.name}-${each.key}"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = each.value.subresource_names
    is_manual_connection           = false
  }
  
  # Private DNS Zone Group - only if DNS zone exists
  dynamic "private_dns_zone_group" {
    for_each = contains(keys(var.private_dns_zone_ids), each.value.private_dns_zone) ? [1] : []
    
    content {
      name                 = "pdzg-${each.key}"
      private_dns_zone_ids = [var.private_dns_zone_ids[each.value.private_dns_zone]]
    }
  }
  
  tags = var.tags
  
  depends_on = [azurerm_storage_account.main]
}

# Storage Containers (optional example containers)
resource "azurerm_storage_container" "example" {
  count = 1
  
  name                 = "example-container"
  storage_account_id   = azurerm_storage_account.main.id
  container_access_type = "private"
  
  depends_on = [azurerm_storage_account.main]
}

# Network Rules (additional security layer)
resource "azurerm_storage_account_network_rules" "main" {
  storage_account_id = azurerm_storage_account.main.id
  
  default_action = "Deny"
  bypass         = ["Metrics", "Logging", "AzureServices"]
  
  # Allow access from the virtual network subnets
  # This is automatically handled by private endpoints
  
  depends_on = [azurerm_storage_account.main]
}
