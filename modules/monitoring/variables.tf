variable "location" {
  description = "Azure region for monitoring resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "ID of the resource group"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "storage_account_id" {
  description = "ID of the storage account to monitor"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account"
  type        = string
}

variable "storage_account_primary_access_key" {
  description = "Primary access key of the storage account"
  type        = string
  sensitive   = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "log_analytics_workspace_sku" {
  description = "SKU for the Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "enable_monitoring" {
  description = "Enable monitoring resources"
  type        = bool
  default     = true
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive alerts"
  type        = list(string)
  default     = []
}

variable "alert_webhook_urls" {
  description = "Map of webhook URLs for alerts"
  type        = map(string)
  default     = {}
}

variable "storage_diagnostic_category_groups" {
  description = "List of diagnostic category groups to enable for storage"
  type        = list(string)
  default     = ["allLogs"]
  validation {
    condition = alltrue([
      for group in var.storage_diagnostic_category_groups : contains(["allLogs", "audit"], group)
    ])
    error_message = "Storage diagnostic category groups must be either 'allLogs' or 'audit'."
  }
}

variable "enable_table_diagnostics" {
  description = "Enable diagnostics for Table service"
  type        = bool
  default     = false
}

variable "enable_queue_diagnostics" {
  description = "Enable diagnostics for Queue service"
  type        = bool
  default     = false
}

variable "enable_file_diagnostics" {
  description = "Enable diagnostics for File service"
  type        = bool
  default     = false
}

variable "enable_advanced_monitoring" {
  description = "Enable advanced monitoring with data collection rules"
  type        = bool
  default     = false
}

variable "enable_network_watcher" {
  description = "Enable Network Watcher for flow logs"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to monitoring resources"
  type        = map(string)
  default     = {}
}