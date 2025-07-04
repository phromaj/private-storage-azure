# Local values for resource naming and configuration
locals {
  # Naming conventions
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : "rg-${var.project_name}-privatelink-${var.environment}-${random_id.storage_suffix.hex}"

  # Generate unique storage account name if not provided
  storage_account_name = var.storage_account_name != null ? var.storage_account_name : "stg${var.project_name}${var.environment}${random_id.storage_suffix.hex}"

  # Virtual machine name
  vm_name = var.vm_name != null ? var.vm_name : "vm-test-${var.environment}"

  # Network names
  vnet_name = "vnet-${var.project_name}-${var.environment}"
  subnet_names = {
    private_endpoints = "snet-privateendpoints"
    compute           = "snet-compute"
  }

  # Private endpoint names
  private_endpoint_name = "pep-${local.storage_account_name}-blob"
  private_dns_zone_name = var.private_dns_zone_name

  # Network security group names
  nsg_names = {
    private_endpoints = "nsg-privateendpoints"
    compute           = "nsg-compute"
  }

  # Monitoring names
  log_analytics_workspace_name = "law-${var.project_name}-${var.environment}"

  # Consolidated tags
  common_tags = merge(
    var.tags,
    var.additional_tags,
    {
      Environment = var.environment
      Project     = var.project_name
      DeployedBy  = "Terraform"
      CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # Subnet configurations
  subnet_configs = {
    private_endpoints = {
      name              = local.subnet_names.private_endpoints
      address_prefixes  = [var.subnet_address_prefixes.private_endpoints]
      service_endpoints = []
    }
    compute = {
      name              = local.subnet_names.compute
      address_prefixes  = [var.subnet_address_prefixes.compute]
      service_endpoints = ["Microsoft.Storage"]
    }
  }

  # Storage account configuration
  storage_config = {
    name                     = local.storage_account_name
    account_tier             = var.storage_account_tier
    account_replication_type = var.storage_replication_type
    account_kind             = "StorageV2"
    access_tier              = "Hot"

    # Security settings
    allow_nested_items_to_be_public = false
    shared_access_key_enabled       = true
    public_network_access_enabled   = false

    # HTTPS and TLS settings
    https_traffic_only_enabled = true
    min_tls_version            = "TLS1_2"

    # Features
    blob_properties = {
      versioning_enabled = var.enable_blob_versioning
      delete_retention_policy = {
        days = var.blob_delete_retention_days
      }
      container_delete_retention_policy = {
        days = var.enable_container_delete_retention ? var.blob_delete_retention_days : 1
      }
    }
  }

  # Private endpoints configuration
  private_endpoints = merge(
    {
      "blob" = {
        subresource_names = ["blob"]
        private_dns_zone  = local.private_dns_zone_name
      }
    },
    var.additional_private_endpoints
  )

  # VM configuration
  vm_config = {
    name = local.vm_name
    size = var.vm_size

    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
      disk_size_gb         = 128
    }

    source_image_reference = var.vm_image

    network_interface = {
      name                          = "nic-${local.vm_name}"
      enable_accelerated_networking = var.enable_accelerated_networking
      ip_configuration = {
        name                          = "internal"
        private_ip_address_allocation = "Dynamic"
      }
    }
  }

  # Network security rules
  nsg_rules = {
    compute = concat(
      var.enable_rdp_access ? [
        {
          name                       = "Allow-RDP-Inbound"
          priority                   = 1000
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "3389"
          source_address_prefix      = var.rdp_source_address_prefix
          destination_address_prefix = "*"
        }
      ] : [],
      [
        # Allow WinRM HTTP for PowerShell remote execution
        {
          name                       = "Allow-WinRM-HTTP-Inbound"
          priority                   = 1100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "5985"
          source_address_prefix      = var.rdp_source_address_prefix
          destination_address_prefix = "*"
        },
        # Allow WinRM HTTPS for PowerShell remote execution
        {
          name                       = "Allow-WinRM-HTTPS-Inbound"
          priority                   = 1110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "5986"
          source_address_prefix      = var.rdp_source_address_prefix
          destination_address_prefix = "*"
        },
        # Allow HTTPS from VNet only (for storage access)
        {
          name                       = "Allow-HTTPS-VNet-Inbound"
          priority                   = 1200
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        },
        # Allow SSH for potential Linux management
        {
          name                       = "Allow-SSH-Inbound"
          priority                   = 1300
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "22"
          source_address_prefix      = var.rdp_source_address_prefix
          destination_address_prefix = "*"
        },
        # Explicitly deny HTTPS from Internet (priority before default allow)
        {
          name                       = "Deny-HTTPS-Internet-Inbound"
          priority                   = 4000
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "Internet"
          destination_address_prefix = "*"
        },
        # Explicitly deny HTTP from Internet
        {
          name                       = "Deny-HTTP-Internet-Inbound"
          priority                   = 4010
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "80"
          source_address_prefix      = "Internet"
          destination_address_prefix = "*"
        },
        # Allow outbound to Azure services
        {
          name                       = "Allow-Azure-Services-Outbound"
          priority                   = 1000
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "AzureCloud"
        },
        # Allow internal VNet communication
        {
          name                       = "Allow-VNet-Outbound"
          priority                   = 1100
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        }
      ]
    )

    private_endpoints = [
      # Allow HTTPS from VNet only
      {
        name                       = "Allow-HTTPS-VNet-Inbound"
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "*"
      },
      # Explicitly deny HTTPS from Internet
      {
        name                       = "Deny-HTTPS-Internet-Inbound"
        priority                   = 4000
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "Internet"
        destination_address_prefix = "*"
      },
      # Explicitly deny HTTP from Internet
      {
        name                       = "Deny-HTTP-Internet-Inbound"
        priority                   = 4010
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "Internet"
        destination_address_prefix = "*"
      }
    ]
  }
}
