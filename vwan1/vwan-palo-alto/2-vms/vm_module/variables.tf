variable "rg_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vm_names" {
  description = "List of VM names"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of existing subnet IDs"
  type        = list(string)
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
}

variable "admin_password" {
  description = "Admin password for the VM"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Size of the VM"
  type        = string
  default     = "Standard_B1s"
}

variable "image_reference" {
  description = "Linux image reference"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}
