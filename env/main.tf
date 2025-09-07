terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.116.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "258a8e61-bb4a-4a2e-99d2-ca7211e4a421"
}

# -------------------------------
# Resource Group
# -------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "demo-rg"
  location = "East US"
}

# -------------------------------
# Virtual Network + Subnet
# -------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "demo-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "demo-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# -------------------------------
# Public IP for LB
# -------------------------------
resource "azurerm_public_ip" "lb_pip" {
  name                = "demo-lb-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# -------------------------------
# Load Balancer
# -------------------------------
resource "azurerm_lb" "lb" {
  name                = "demo-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicFrontend"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

# Backend Pool
resource "azurerm_lb_backend_address_pool" "bepool" {
  name            = "demo-bepool"
  loadbalancer_id = azurerm_lb.lb.id
}

# Health Probe
resource "azurerm_lb_probe" "probe" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  port                = 22
}

# LB Rule
resource "azurerm_lb_rule" "lbrule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bepool.id]
  probe_id                       = azurerm_lb_probe.probe.id
}

# -------------------------------
# NICs for 2 VMs
# -------------------------------
resource "azurerm_network_interface" "nic1" {
  name                = "vm1-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic2" {
  name                = "vm2-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# -------------------------------
# NICs association with Backend Pool
# -------------------------------
resource "azurerm_network_interface_backend_address_pool_association" "assoc1" {
  network_interface_id    = azurerm_network_interface.nic1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bepool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "assoc2" {
  network_interface_id    = azurerm_network_interface.nic2.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bepool.id
}

# -------------------------------
# Linux VMs
# -------------------------------
resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "demo-vm1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  admin_password      = "P@ssw0rd123!"       # apna strong password rakhna
  disable_password_authentication = false
  network_interface_ids = [azurerm_network_interface.nic1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "demo-vm2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  admin_password      = "P@ssw0rd123!"       # apna strong password rakhna
  disable_password_authentication = false
  network_interface_ids = [azurerm_network_interface.nic2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}
