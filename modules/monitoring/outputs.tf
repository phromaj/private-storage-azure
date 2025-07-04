output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].name : null
}

output "action_group_id" {
  description = "ID of the monitoring action group"
  value       = var.enable_monitoring ? azurerm_monitor_action_group.storage_alerts[0].id : null
}

output "data_collection_endpoint_id" {
  description = "ID of the data collection endpoint"
  value       = var.enable_monitoring && var.enable_advanced_monitoring ? azurerm_monitor_data_collection_endpoint.main[0].id : null
}

output "data_collection_rule_id" {
  description = "ID of the data collection rule"
  value       = var.enable_monitoring && var.enable_advanced_monitoring ? azurerm_monitor_data_collection_rule.storage_logs[0].id : null
}