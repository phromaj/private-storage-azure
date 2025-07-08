# Azure Monitor Module for Storage Account Monitoring
# This module provides comprehensive monitoring and auditing for Azure Storage Account with Private Endpoints

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_monitoring ? 1 : 0

  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.log_retention_days

  tags = var.tags
}

# Storage Insights for enhanced monitoring
resource "azurerm_log_analytics_storage_insights" "main" {
  count = var.enable_monitoring ? 1 : 0

  name                = "storage-insights-${var.storage_account_name}"
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main[0].id
  storage_account_id  = var.storage_account_id
  storage_account_key = var.storage_account_primary_access_key

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Action Group for monitoring alerts
resource "azurerm_monitor_action_group" "storage_alerts" {
  count = var.enable_monitoring ? 1 : 0

  name                = "ag-storage-alerts-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "stgalerts"

  dynamic "email_receiver" {
    for_each = var.alert_email_addresses
    content {
      name          = "email-${email_receiver.value}"
      email_address = email_receiver.value
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.alert_webhook_urls
    content {
      name        = "webhook-${webhook_receiver.key}"
      service_uri = webhook_receiver.value
    }
  }

  tags = var.tags
}

# Activity Log Alert for Storage Account modifications
resource "azurerm_monitor_activity_log_alert" "storage_modifications" {
  count = var.enable_monitoring ? 1 : 0

  name                = "alert-storage-modifications-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  scopes              = [var.resource_group_id]
  description         = "Alerte pour les modifications de configuration du compte de stockage"

  criteria {
    resource_id    = var.storage_account_id
    operation_name = "Microsoft.Storage/storageAccounts/write"
    category       = "Administrative"
  }

  action {
    action_group_id = azurerm_monitor_action_group.storage_alerts[0].id

    webhook_properties = {
      source      = "terraform"
      environment = var.environment
      alert_type  = "storage_modification"
    }
  }

  tags = var.tags
}

# Activity Log Alert for Private Endpoint modifications
resource "azurerm_monitor_activity_log_alert" "private_endpoint_modifications" {
  count = var.enable_monitoring ? 1 : 0

  name                = "alert-private-endpoint-modifications-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  scopes              = [var.resource_group_id]
  description         = "Alerte pour les modifications de configuration des private endpoints"

  criteria {
    operation_name = "Microsoft.Network/privateEndpoints/write"
    category       = "Administrative"
  }

  action {
    action_group_id = azurerm_monitor_action_group.storage_alerts[0].id

    webhook_properties = {
      source      = "terraform"
      environment = var.environment
      alert_type  = "private_endpoint_modification"
    }
  }

  tags = var.tags
}

# Diagnostic Settings for Storage Account - Blob Service
resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  count = var.enable_monitoring ? 1 : 0

  name                       = "diag-${var.storage_account_name}-blob"
  target_resource_id         = "${var.storage_account_id}/blobServices/default/"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  dynamic "enabled_log" {
    for_each = var.storage_diagnostic_category_groups
    content {
      category_group = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Diagnostic Settings for Storage Account - Table Service
resource "azurerm_monitor_diagnostic_setting" "storage_table" {
  count = var.enable_monitoring && var.enable_table_diagnostics ? 1 : 0

  name                       = "diag-${var.storage_account_name}-table"
  target_resource_id         = "${var.storage_account_id}/tableServices/default/"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  dynamic "enabled_log" {
    for_each = var.storage_diagnostic_category_groups
    content {
      category_group = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Diagnostic Settings for Storage Account - Queue Service
resource "azurerm_monitor_diagnostic_setting" "storage_queue" {
  count = var.enable_monitoring && var.enable_queue_diagnostics ? 1 : 0

  name                       = "diag-${var.storage_account_name}-queue"
  target_resource_id         = "${var.storage_account_id}/queueServices/default/"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  dynamic "enabled_log" {
    for_each = var.storage_diagnostic_category_groups
    content {
      category_group = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Diagnostic Settings for Storage Account - File Service
resource "azurerm_monitor_diagnostic_setting" "storage_file" {
  count = var.enable_monitoring && var.enable_file_diagnostics ? 1 : 0

  name                       = "diag-${var.storage_account_name}-file"
  target_resource_id         = "${var.storage_account_id}/fileServices/default/"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  dynamic "enabled_log" {
    for_each = var.storage_diagnostic_category_groups
    content {
      category_group = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Data Collection Endpoint for advanced monitoring
resource "azurerm_monitor_data_collection_endpoint" "main" {
  count = var.enable_monitoring && var.enable_advanced_monitoring ? 1 : 0

  name                = "dce-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Point de collecte de données pour le monitoring du stockage ${var.project_name}"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Data Collection Rule for structured log collection
resource "azurerm_monitor_data_collection_rule" "storage_logs" {
  count = var.enable_monitoring && var.enable_advanced_monitoring ? 1 : 0

  name                        = "dcr-storage-logs-${var.project_name}-${var.environment}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.main[0].id
  description                 = "Règle de collecte de données pour les logs du compte de stockage"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main[0].id
      name                  = "log-analytics-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-StorageBlobLogs", "Microsoft-StorageTableLogs", "Microsoft-StorageQueueLogs", "Microsoft-StorageFileLogs"]
    destinations = ["log-analytics-destination"]
  }

  tags = var.tags

  depends_on = [azurerm_log_analytics_workspace.main, azurerm_monitor_data_collection_endpoint.main]
}
