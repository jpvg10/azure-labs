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

variable "storage_account_name" {
  type = string
}

variable "web_app_name" {
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

# Storage account

resource "azurerm_storage_account" "lab_account" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.storage.name
  location                        = azurerm_resource_group.storage.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = false
}

output "lab_account_id" {
  value = azurerm_storage_account.lab_account.id
}

resource "azurerm_storage_container" "uploaded_files" {
  name                  = "uploaded-files"
  storage_account_id    = azurerm_storage_account.lab_account.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "storage_policy" {
  storage_account_id = azurerm_storage_account.lab_account.id

  rule {
    name    = "Delete blobs after 7 days"
    enabled = true
    filters {
      prefix_match = [azurerm_storage_container.uploaded_files.name]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 7
      }
    }
  }
}

# App service

resource "azurerm_service_plan" "lab_plan" {
  name                = "lab_plan"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  os_type             = "Linux"
  sku_name            = "F1" # Free
}

resource "azurerm_linux_web_app" "lab_webapp" {
  name                                           = var.web_app_name
  resource_group_name                            = azurerm_resource_group.storage.name
  location                                       = azurerm_service_plan.lab_plan.location
  service_plan_id                                = azurerm_service_plan.lab_plan.id
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    always_on = false
  }
}
