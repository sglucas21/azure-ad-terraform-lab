resource "azurerm_resource_group" "rg" {
  name     = "rg-ad-lab"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-ad-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  dns_servers = ["10.0.1.10"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-ad-lab"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-ad-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP-From-My-IP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.my_public_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "dc_pip" {
  name                = "pip-ad-dc-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "client_pip" {
  name                = "pip-client-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "dc_nic" {
  name                = "nic-ad-dc-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dns_servers = ["10.0.1.10"]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.dc_pip.id
  }
}

resource "azurerm_network_interface" "client_nic" {
  name                = "nic-client-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dns_servers = ["10.0.1.10"]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.client_pip.id
  }
}

resource "azurerm_windows_virtual_machine" "dc" {
  name                = "ad-dc-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size

  admin_username = var.local_admin_username
  admin_password = var.local_admin_password

  network_interface_ids = [
    azurerm_network_interface.dc_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "client" {
  name                = "client-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size

  admin_username = var.local_admin_username
  admin_password = var.local_admin_password

  network_interface_ids = [
    azurerm_network_interface.client_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "promote_dc" {
  name                 = "promote-dc"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    fileUris = [
      "https://raw.githubusercontent.com/sglucas21/azure-ad-terraform-lab/main/scripts/01-promote-dc.ps1",
      "https://raw.githubusercontent.com/sglucas21/azure-ad-terraform-lab/main/scripts/02-post-reboot-ad-config.ps1"
    ]
  })

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -File 01-promote-dc.ps1"
  })

  depends_on = [
    azurerm_windows_virtual_machine.dc
  ]
}
resource "time_sleep" "wait_for_domain" {
  depends_on      = [azurerm_virtual_machine_extension.promote_dc]
  create_duration = "20m"
}

resource "azurerm_virtual_machine_extension" "join_client" {
  name                 = "join-client-to-domain"
  virtual_machine_id   = azurerm_windows_virtual_machine.client.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    fileUris = [
      "https://raw.githubusercontent.com/sglucas21/azure-ad-terraform-lab/main/scripts/03-join-domain.ps1"
    ]
  })

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -File 03-join-domain.ps1"
  })

  depends_on = [
    time_sleep.wait_for_domain,
    azurerm_windows_virtual_machine.client
  ]
}