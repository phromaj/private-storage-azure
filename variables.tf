variable "subscription_id" {
  description = "The Azure subscription ID to use for deployment"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "Subscription ID must be a valid UUID."
  }
}

variable "location" {
  description = "The Azure region where all resources will be created"
  type        = string
  default     = "West Europe"

  validation {
    condition = contains([
      "West Europe", "East US", "East US 2", "West US 2", "Central US",
      "North Europe", "Southeast Asia", "Australia East", "UK South",
      "Canada Central", "France Central", "Germany West Central",
      "Japan East", "Korea Central", "South Africa North"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod, poc)"
  type        = string
  default     = "poc"

  validation {
    condition     = length(var.environment) <= 8 && can(regex("^[a-z0-9]+$", var.environment))
    error_message = "Environment must be alphanumeric, lowercase, and max 8 characters."
  }
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group. If not provided, will be auto-generated."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "datasafe"

  validation {
    condition     = length(var.project_name) <= 10 && can(regex("^[a-z0-9]+$", var.project_name))
    error_message = "Project name must be alphanumeric, lowercase, and max 10 characters."
  }
}

# Networking Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "VNet address space must be a valid CIDR block."
  }
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
variable "storage_account_name" {
  description = "Name of the storage account. If not provided, will be auto-generated."
  type        = string
  default     = null

  validation {
    condition = (
      var.storage_account_name == null ? true : (
        length(var.storage_account_name) >= 3 &&
        length(var.storage_account_name) <= 24 &&
        can(regex("^[a-z0-9]+$", var.storage_account_name))
      )
    )
    error_message = "Storage account name must be 3-24 characters, alphanumeric, lowercase only."
  }
}

variable "storage_account_tier" {
  description = "Performance tier of the storage account"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage account tier must be Standard or Premium."
  }
}

variable "storage_replication_type" {
  description = "Replication type for the storage account"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be LRS, GRS, RAGRS, ZRS, GZRS, or RAGZRS."
  }
}

variable "enable_blob_versioning" {
  description = "Enable blob versioning for the storage account"
  type        = bool
  default     = true
}

variable "enable_container_delete_retention" {
  description = "Enable container delete retention policy"
  type        = bool
  default     = true
}

variable "blob_delete_retention_days" {
  description = "Number of days to retain deleted blobs"
  type        = number
  default     = 7

  validation {
    condition     = var.blob_delete_retention_days >= 1 && var.blob_delete_retention_days <= 365
    error_message = "Blob delete retention days must be between 1 and 365."
  }
}

# Private Endpoint Configuration
variable "private_dns_zone_name" {
  description = "Name of the private DNS zone. If not provided, will use default Azure zone."
  type        = string
  default     = "privatelink.blob.core.windows.net"
}

variable "additional_private_endpoints" {
  description = "Additional private endpoints to create for the storage account"
  type = map(object({
    subresource_names = list(string)
    private_dns_zone  = optional(string)
  }))
  default = {}

  # Example:
  # additional_private_endpoints = {
  #   "table" = {
  #     subresource_names = ["table"]
  #     private_dns_zone  = "privatelink.table.core.windows.net"
  #   }
  #   "queue" = {
  #     subresource_names = ["queue"]
  #     private_dns_zone  = "privatelink.queue.core.windows.net"
  #   }
  # }
}

# Virtual Machine Configuration
variable "vm_name" {
  description = "Name of the test virtual machine"
  type        = string
  default     = null
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"

  validation {
    condition = contains([
      "Standard_B1s", "Standard_B1ms", "Standard_B2s", "Standard_B2ms",
      "Standard_B4ms", "Standard_D2s_v3", "Standard_D4s_v3"
    ], var.vm_size)
    error_message = "VM size must be a valid Azure VM size for testing purposes."
  }
}

variable "admin_username" {
  description = "Administrator username for the virtual machine"
  type        = string

  validation {
    condition     = length(var.admin_username) >= 3 && length(var.admin_username) <= 20
    error_message = "Admin username must be between 3 and 20 characters."
  }
}

variable "admin_password" {
  description = "Administrator password for the virtual machine"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.admin_password) >= 12 &&
      length(var.admin_password) <= 123 &&
      can(regex("[a-z]", var.admin_password)) &&
      can(regex("[A-Z]", var.admin_password)) &&
      can(regex("[0-9]", var.admin_password)) &&
      can(regex("[!@#$%^&*()_+=-]", var.admin_password))
    )
    error_message = "Password must be 12-123 characters with at least one uppercase letter, one lowercase letter, one digit, and one special character (!@#$%^&*()_+=-)."
  }
}

variable "vm_image" {
  description = "Virtual machine image configuration"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

variable "enable_accelerated_networking" {
  description = "Enable accelerated networking for the VM"
  type        = bool
  default     = false
}

# Monitoring and Security
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

  validation {
    condition     = contains(["Free", "PerNode", "Premium", "Standard", "Standalone", "Unlimited", "CapacityReservation", "PerGB2018"], var.log_analytics_workspace_sku)
    error_message = "Log Analytics workspace SKU must be a valid option."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 30 and 730."
  }
}

# Monitoring Configuration
variable "alert_email_addresses" {
  description = "List of email addresses to receive monitoring alerts"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.alert_email_addresses : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid."
  }
}

variable "alert_webhook_urls" {
  description = "Map of webhook URLs for monitoring alerts"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for url in values(var.alert_webhook_urls) : can(regex("^https?://", url))
    ])
    error_message = "All webhook URLs must be valid HTTP/HTTPS URLs."
  }
}

variable "storage_diagnostic_category_groups" {
  description = "List of diagnostic category groups to enable for storage services"
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
  description = "Enable diagnostic settings for table storage service"
  type        = bool
  default     = true
}

variable "enable_queue_diagnostics" {
  description = "Enable diagnostic settings for queue storage service"
  type        = bool
  default     = true
}

variable "enable_file_diagnostics" {
  description = "Enable diagnostic settings for file storage service"
  type        = bool
  default     = true
}

variable "enable_advanced_monitoring" {
  description = "Enable advanced monitoring features like data collection rules"
  type        = bool
  default     = false
}

# Network Security
variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access the VM via RDP (for testing only)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.allowed_ip_ranges : can(cidrhost(ip, 0))
    ])
    error_message = "All IP ranges must be valid CIDR blocks."
  }
}

variable "enable_rdp_access" {
  description = "Enable RDP access to the test VM (for testing purposes only)"
  type        = bool
  default     = true
}

variable "rdp_source_address_prefix" {
  description = "Source address prefix for RDP access"
  type        = string
  default     = "*"
}

# Tagging
variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default = {
    Project     = "DataSafe"
    Environment = "POC"
    ManagedBy   = "Terraform"
  }
}

variable "additional_tags" {
  description = "Additional tags to merge with default tags"
  type        = map(string)
  default     = {}
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

variable "create_bastion" {
  description = "Whether to create Azure Bastion for secure VM access"
  type        = bool
  default     = false
}

variable "enable_private_dns_zone" {
  description = "Whether to create and configure private DNS zone"
  type        = bool
  default     = true
}
