terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.17.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }
  }
}

variable "subscription_id" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "user_principal_name" {
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
  name                            = var.storage_account_name
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

data "azuread_user" "lab_user_account" {
  user_principal_name = var.user_principal_name
}

resource "azurerm_role_assignment" "lab_role" {
  scope                = azurerm_storage_account.lab_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_user.lab_user_account.object_id
}
