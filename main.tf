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

# Monitoring Module
module "monitoring" {
  count = var.create_monitoring ? 1 : 0

  source = "./modules/monitoring"

  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  project_name        = var.project_name
  environment         = var.environment

  storage_account_id                 = module.storage.storage_account_id
  storage_account_name               = local.storage_account_name
  storage_account_primary_access_key = module.storage.storage_account_primary_access_key

  log_analytics_workspace_name = local.log_analytics_workspace_name
  log_analytics_workspace_sku  = var.log_analytics_workspace_sku
  log_retention_days           = var.log_retention_days

  enable_monitoring                  = var.create_monitoring
  alert_email_addresses              = var.alert_email_addresses
  alert_webhook_urls                 = var.alert_webhook_urls
  storage_diagnostic_category_groups = var.storage_diagnostic_category_groups

  enable_table_diagnostics   = var.enable_table_diagnostics
  enable_queue_diagnostics   = var.enable_queue_diagnostics
  enable_file_diagnostics    = var.enable_file_diagnostics
  enable_advanced_monitoring = var.enable_advanced_monitoring
  enable_network_watcher     = var.enable_network_watcher

  tags = local.common_tags

  depends_on = [module.storage]
}
