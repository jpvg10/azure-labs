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

variable "storage_account_name" {
  type = string
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

resource "azurerm_network_security_group" "vm_ssh_nsg" {
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

resource "azurerm_subnet" "azure_subnet_vms" {
  name                 = "azure-vms"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "azure_subnet_storage" {
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

resource "azurerm_subnet" "onprem_subnet_dev_laptops" {
  name                 = "onprem-dev-laptops"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Bastion

resource "azurerm_subnet" "onprem_subnet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.1.3.0/24"]
}

module "onprem_bastion" {
  source         = "./bastion"
  bastion_name   = "onprem-bastion"
  resource_group = azurerm_resource_group.networks
  subnet_id      = azurerm_subnet.onprem_subnet_bastion.id
}

# VMs

module "dev_laptop" {
  source           = "./vm"
  vm_name          = "dev-laptop"
  resource_group   = azurerm_resource_group.networks
  subnet_id        = azurerm_subnet.onprem_subnet_dev_laptops.id
  default_password = var.vm_default_password
  nsg_id           = azurerm_network_security_group.vm_ssh_nsg.id
}

module "cloud_server" {
  source           = "./vm"
  vm_name          = "cloud-server"
  resource_group   = azurerm_resource_group.networks
  subnet_id        = azurerm_subnet.azure_subnet_vms.id
  default_password = var.vm_default_password
  nsg_id           = azurerm_network_security_group.vm_ssh_nsg.id
}

output "cloud_server_ip" {
  value = module.cloud_server.vm_ip
}

# Storage account

resource "azurerm_storage_account" "storage" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.networks.name
  location                        = azurerm_resource_group.networks.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = true
  public_network_access_enabled   = false
}

resource "azurerm_storage_container" "public_container" {
  name                  = "public-files"
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "container" # Anonymous user can read all blobs in the container
}

# Private endpoint

resource "azurerm_private_endpoint" "endpoint" {
  name                = "storage-endpoint"
  location            = azurerm_resource_group.networks.location
  resource_group_name = azurerm_resource_group.networks.name
  subnet_id           = azurerm_subnet.azure_subnet_storage.id

  private_service_connection {
    name                           = "storage-private-service-connection"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_zone.id]
  }
}

resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.networks.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  name                  = "storage-link"
  resource_group_name   = azurerm_resource_group.networks.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.azure.id
}

# VPN

resource "azurerm_subnet" "onprem_subnet_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.1.4.0/24"]
}

module "onprem_gateway" {
  source         = "./vpn-gateway"
  name           = "onprem-gateway"
  resource_group = azurerm_resource_group.networks
  subnet_id      = azurerm_subnet.onprem_subnet_gateway.id
}

resource "azurerm_subnet" "azure_subnet_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networks.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.0.4.0/24"]
}

module "azure_gateway" {
  source         = "./vpn-gateway"
  name           = "azure-gateway"
  resource_group = azurerm_resource_group.networks
  subnet_id      = azurerm_subnet.azure_subnet_gateway.id
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_azure" {
  name                = "onprem-to-azure"
  location            = azurerm_resource_group.networks.location
  resource_group_name = azurerm_resource_group.networks.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.onprem_gateway.gateway_id
  peer_virtual_network_gateway_id = module.azure_gateway.gateway_id

  shared_key = var.vpn_gateway_shared_key
}

resource "azurerm_virtual_network_gateway_connection" "azure_to_onprem" {
  name                = "azure-to-onprem"
  location            = azurerm_resource_group.networks.location
  resource_group_name = azurerm_resource_group.networks.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.azure_gateway.gateway_id
  peer_virtual_network_gateway_id = module.onprem_gateway.gateway_id

  shared_key = var.vpn_gateway_shared_key
}
