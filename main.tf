# Random ID for unique storage account naming
resource "random_id" "storage_suffix" {
  byte_length = 4
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  vnet_name          = local.vnet_name
  vnet_address_space = var.vnet_address_space
  subnet_configs     = local.subnet_configs

  private_dns_zone_name   = local.private_dns_zone_name
  enable_private_dns_zone = var.enable_private_dns_zone

  nsg_names = local.nsg_names
  nsg_rules = local.nsg_rules

  tags = local.common_tags
}

# Storage Module
module "storage" {
  source = "./modules/storage"

  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  storage_config    = local.storage_config
  private_endpoints = local.private_endpoints

  subnet_id            = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_ids = module.networking.private_dns_zone_ids

  tags = local.common_tags

  depends_on = [module.networking]
}

# Compute Module (Test VM)
module "compute" {
  count = var.create_test_vm ? 1 : 0

  source = "./modules/compute"

  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  vm_config      = local.vm_config
  subnet_id      = module.networking.subnet_ids["compute"]
  admin_username = var.admin_username
  admin_password = var.admin_password

  tags = local.common_tags

  depends_on = [module.networking]
}

# Monitoring Resources (Optional)
resource "azurerm_log_analytics_workspace" "main" {
  count = var.create_monitoring ? 1 : 0

  name                = local.log_analytics_workspace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.log_retention_days

  tags = local.common_tags
}

# Storage Account Diagnostics - Removed due to unsupported categories
# The StorageRead, StorageWrite, and StorageDelete categories are not supported
# for storage account diagnostic settings in the current Azure API version

# Network Watcher (for flow logs and monitoring)
resource "azurerm_network_watcher" "main" {
  count = var.enable_network_watcher ? 1 : 0

  name                = "nw-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}
