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

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "storage" {
  name     = "storage"
  location = "Sweden Central"
}

resource "azurerm_storage_account" "lab_account" {
  name                            = "labaccountjpvg"
  resource_group_name             = azurerm_resource_group.storage.name
  location                        = azurerm_resource_group.storage.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "uploaded_files" {
  name                  = "uploaded-files"
  storage_account_id    = azurerm_storage_account.lab_account.id
  container_access_type = "private"
}

output "lab_account_id" {
  value = azurerm_storage_account.lab_account.id
}
