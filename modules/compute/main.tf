# Public IP (optional)
resource "azurerm_public_ip" "main" {
  count = var.enable_public_ip ? 1 : 0
  
  name                = "pip-${var.vm_config.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = var.tags
}

# Network Interface
resource "azurerm_network_interface" "main" {
  name                = var.vm_config.network_interface.name
  location            = var.location
  resource_group_name = var.resource_group_name
  
  ip_configuration {
    name                          = var.vm_config.network_interface.ip_configuration.name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.vm_config.network_interface.ip_configuration.private_ip_address_allocation
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.main[0].id : null
  }
  
  tags = var.tags
}

# Virtual Machine
resource "azurerm_windows_virtual_machine" "main" {
  name                = var.vm_config.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_config.size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  
  network_interface_ids = [
    azurerm_network_interface.main.id
  ]
  
  os_disk {
    caching              = var.vm_config.os_disk.caching
    storage_account_type = var.vm_config.os_disk.storage_account_type
    disk_size_gb         = var.vm_config.os_disk.disk_size_gb
  }
  
  source_image_reference {
    publisher = var.vm_config.source_image_reference.publisher
    offer     = var.vm_config.source_image_reference.offer
    sku       = var.vm_config.source_image_reference.sku
    version   = var.vm_config.source_image_reference.version
  }
  
  # Enable automatic updates and timezone
  timezone                      = "UTC"
  patch_assessment_mode        = "ImageDefault"
  patch_mode                   = "AutomaticByOS"
  
  tags = var.tags
}

# VM Extensions removed due to deployment issues
# The IIS extension was failing due to PowerShell syntax errors in the commandToExecute
# The PowerShell extension was also removed as it's not essential for the core functionality
# If needed, these can be configured manually after VM deployment
