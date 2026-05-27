variable "location" {
  type    = string
  default = "eastus"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "my_public_ip" {
  type        = string
  description = "Your public IP in CIDR format, example: 1.2.3.4/32"
}

variable "local_admin_username" {
  type    = string
  default = "labadmin"
}

variable "local_admin_password" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type    = string
  default = "lab.local"
}

variable "netbios_name" {
  type    = string
  default = "LAB"
}

variable "dsrm_password" {
  type      = string
  sensitive = true
}