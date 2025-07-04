# =============================================================================
# EXAMPLE VARIABLES
# =============================================================================


variable "location" {
  description = "The Azure region where all resources will be created"
  type        = string
  default     = "West Europe"
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod, poc)"
  type        = string
  default     = "poc"
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "datasafe"
}

# Networking Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for subnets"
  type = object({
    private_endpoints = string
    compute           = string
  })
  default = {
    private_endpoints = "10.10.1.0/24"
    compute           = "10.10.2.0/24"
  }
}

# Storage Configuration
variable "storage_account_tier" {
  description = "Performance tier of the storage account"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Replication type for the storage account"
  type        = string
  default     = "LRS"
}

variable "enable_blob_versioning" {
  description = "Enable blob versioning for the storage account"
  type        = bool
  default     = true
}

variable "blob_delete_retention_days" {
  description = "Number of days to retain deleted blobs"
  type        = number
  default     = 7
}

# Virtual Machine Configuration
variable "admin_username" {
  description = "Administrator username for the virtual machine"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Administrator password for the virtual machine"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!@#"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
}

# Security Configuration
variable "enable_rdp_access" {
  description = "Enable RDP access to the test VM"
  type        = bool
  default     = true
}

variable "rdp_source_address_prefix" {
  description = "Source address prefix for RDP access"
  type        = string
  default     = "*"
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access the VM via RDP"
  type        = list(string)
  default     = []
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable monitoring and diagnostics"
  type        = bool
  default     = true
}

variable "enable_network_watcher" {
  description = "Enable Network Watcher for the region"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "alert_email_addresses" {
  description = "List of email addresses for monitoring alerts"
  type        = list(string)
  default     = []
}

variable "alert_webhook_urls" {
  description = "List of webhook URLs for monitoring alerts"
  type        = list(string)
  default     = []
}

variable "storage_diagnostic_category_groups" {
  description = "Storage diagnostic category groups to enable"
  type        = list(string)
  default     = ["audit", "allLogs"]
}

variable "enable_table_diagnostics" {
  description = "Enable diagnostics for table storage"
  type        = bool
  default     = true
}

variable "enable_queue_diagnostics" {
  description = "Enable diagnostics for queue storage"
  type        = bool
  default     = true
}

variable "enable_file_diagnostics" {
  description = "Enable diagnostics for file storage"
  type        = bool
  default     = true
}

variable "enable_advanced_monitoring" {
  description = "Enable advanced monitoring features"
  type        = bool
  default     = true
}

# Feature Flags
variable "create_test_vm" {
  description = "Whether to create a test virtual machine"
  type        = bool
  default     = true
}

variable "create_monitoring" {
  description = "Whether to create monitoring resources"
  type        = bool
  default     = true
}

variable "enable_private_dns_zone" {
  description = "Whether to create and configure private DNS zone"
  type        = bool
  default     = true
}

variable "create_bastion" {
  description = "Whether to create Azure Bastion for secure VM access"
  type        = bool
  default     = false
}

# Advanced Configuration
variable "additional_private_endpoints" {
  description = "Additional private endpoints to create for the storage account"
  type = map(object({
    subresource_names = list(string)
    private_dns_zone  = optional(string)
  }))
  default = {}
}

# Tagging
variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default = {
    Project     = "DataSafe"
    Environment = "POC"
    ManagedBy   = "Terraform"
    Example     = "Complete"
  }
}

variable "subscription_id" {
  description = "The Azure subscription ID to use for deployment"
  type        = string
}

variable "additional_tags" {
  description = "Additional tags to merge with default tags"
  type        = map(string)
  default = {
    Owner      = "Cloud Team"
    Purpose    = "Private Storage Demo"
    CostCenter = "IT-001"
  }
}
