variable "location" {
  description = "Azure region for compute resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "vm_config" {
  description = "Virtual machine configuration"
  type = object({
    name = string
    size = string
    os_disk = object({
      caching              = string
      storage_account_type = string
      disk_size_gb         = number
    })
    source_image_reference = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    network_interface = object({
      name                          = string
      enable_accelerated_networking = bool
      ip_configuration = object({
        name                          = string
        private_ip_address_allocation = string
      })
    })
  })
}

variable "subnet_id" {
  description = "ID of the subnet for the VM"
  type        = string
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
}

variable "admin_password" {
  description = "Administrator password for the VM"
  type        = string
  sensitive   = true
}

variable "enable_public_ip" {
  description = "Whether to create a public IP for the VM"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to compute resources"
  type        = map(string)
  default     = {}
}
