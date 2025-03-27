variable "bastion_name" {
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

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.bastion_name}-public-ip"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = var.bastion_name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  # sku                 = "Standard"

  ip_configuration {
    name                 = "${var.bastion_name}-ip-configuration"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}
