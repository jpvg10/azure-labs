terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.17.0"
    }
  }
}

variable "subscription_id" {
  type = string
}

variable "vm_default_password" {
  type      = string
  sensitive = true
}

variable "vpn_gateway_shared_key" {
  type      = string
  sensitive = true
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "networks" {
  name     = "networks"
  location = "Sweden Central"
}

# NSG

resource "azurerm_network_security_group" "vm-ssh-nsg" {
  name                = "vm-ssh-nsg"
  location            = azurerm_resource_group.networks.location
  resource_group_name = azurerm_resource_group.networks.name

  security_rule {
    name                       = "HTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Azure network

resource "azurerm_virtual_network" "azure" {
  name                = "vnet-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.networks.location
  resource_group_name = azurerm_resource_group.networks.name
}

resource "azurerm_subnet" "azure-subnet-vms" {
  name                 = "azure-vms"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "azure-subnet-storage" {
  name                 = "azure-storage"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.0.2.0/24"]
}

# On-prem network

resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-onprem"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.networks.location
  resource_group_name = azurerm_resource_group.networks.name
}

resource "azurerm_subnet" "onprem-subnet-dev-laptops" {
  name                 = "onprem-dev-laptops"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Bastion

resource "azurerm_subnet" "onprem-subnet-bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.1.3.0/24"]
}

module "onprem_bastion" {
  source         = "./bastion"
  bastion_name   = "onprem-bastion"
  resource_group = azurerm_resource_group.networks
  subnet_id      = azurerm_subnet.onprem-subnet-bastion.id
}

# VMs

module "dev_laptop" {
  source           = "./vm"
  vm_name          = "dev-laptop"
  resource_group   = azurerm_resource_group.networks
  subnet_id        = azurerm_subnet.onprem-subnet-dev-laptops.id
  default_password = var.vm_default_password
  nsg_id           = azurerm_network_security_group.vm-ssh-nsg.id
}

output "dev_laptop_id" {
  value = module.dev_laptop.vm_id
}

module "cloud_server" {
  source           = "./vm"
  vm_name          = "cloud-server"
  resource_group   = azurerm_resource_group.networks
  subnet_id        = azurerm_subnet.azure-subnet-vms.id
  default_password = var.vm_default_password
  nsg_id           = azurerm_network_security_group.vm-ssh-nsg.id
}

# VPN

resource "azurerm_subnet" "onprem-subnet-gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.1.4.0/24"]
}

module "onprem-gateway" {
  source         = "./vpn-gateway"
  name           = "onprem-gateway"
  resource_group = azurerm_resource_group.networks
  subnet_id      = azurerm_subnet.onprem-subnet-gateway.id
}

resource "azurerm_subnet" "azure-subnet-gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.0.4.0/24"]
}

module "azure-gateway" {
  source         = "./vpn-gateway"
  name           = "azure-gateway"
  resource_group = azurerm_resource_group.networks
  subnet_id      = azurerm_subnet.azure-subnet-gateway.id
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_azure" {
  name                = "onprem-to-azure"
  location            = azurerm_resource_group.networks.location
  resource_group_name = azurerm_resource_group.networks.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.onprem-gateway.gateway_id
  peer_virtual_network_gateway_id = module.azure-gateway.gateway_id

  shared_key = var.vpn_gateway_shared_key
}

resource "azurerm_virtual_network_gateway_connection" "azure_to_onprem" {
  name                = "azure-to-onprem"
  location            = azurerm_resource_group.networks.location
  resource_group_name = azurerm_resource_group.networks.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.azure-gateway.gateway_id
  peer_virtual_network_gateway_id = module.onprem-gateway.gateway_id

  shared_key = var.vpn_gateway_shared_key
}
