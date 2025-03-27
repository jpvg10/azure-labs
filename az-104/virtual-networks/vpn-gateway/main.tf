variable "name" {
  type = string
}

variable "resource_group" {
  type = object({
    name     = string
    location = string
  })
}

variable "subnet_id" {
  type = string
}

resource "azurerm_public_ip" "ip" {
  name                = "${var.name}-public-ip"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "gateway" {
  name                = "${var.name}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw2"

  ip_configuration {
    name                          = "${var.name}-gateway-config"
    public_ip_address_id          = azurerm_public_ip.ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.subnet_id
  }
}

output "gateway_id" {
  value = azurerm_virtual_network_gateway.gateway.id
}
