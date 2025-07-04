# =============================================================================
# COMPLETE PRIVATE STORAGE INFRASTRUCTURE EXAMPLE
# =============================================================================
# This example demonstrates a complete deployment of the private storage
# infrastructure with all features enabled.

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

provider "random" {}

# =============================================================================
# CALL THE ROOT MODULE
# =============================================================================

module "private_storage_infrastructure" {
  source = "../../"  # Points to the root module
  
  # Basic Configuration
  location     = var.location
  environment  = var.environment
  project_name = var.project_name
  
  # Networking
  vnet_address_space      = var.vnet_address_space
  subnet_address_prefixes = var.subnet_address_prefixes
  
  # Storage Configuration
  storage_account_tier       = var.storage_account_tier
  storage_replication_type   = var.storage_replication_type
  enable_blob_versioning     = var.enable_blob_versioning
  blob_delete_retention_days = var.blob_delete_retention_days
  
  # Virtual Machine
  admin_username = var.admin_username
  admin_password = var.admin_password
  vm_size        = var.vm_size
  
  # Security
  enable_rdp_access            = var.enable_rdp_access
  rdp_source_address_prefix    = var.rdp_source_address_prefix
  allowed_ip_ranges           = var.allowed_ip_ranges
  
  # Monitoring
  enable_monitoring           = var.enable_monitoring
  enable_network_watcher      = var.enable_network_watcher
  log_analytics_workspace_sku = var.log_analytics_workspace_sku
  log_retention_days          = var.log_retention_days
  
  # Feature Flags
  create_test_vm              = var.create_test_vm
  create_monitoring           = var.create_monitoring
  enable_private_dns_zone     = var.enable_private_dns_zone
  create_bastion              = var.create_bastion
  
  # Advanced Configuration
  additional_private_endpoints = var.additional_private_endpoints
  
  # Tagging
  tags            = var.tags
  additional_tags = var.additional_tags
}
