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

variable "web_app_name" {
  type = string
}

variable "github_username" {
  type = string
}

variable "github_repo" {
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
  ftp_publish_basic_authentication_enabled       = false

  site_config {
    always_on = false # Required for F1 app service plan

    application_stack {
      node_version = "20-lts"
    }
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 2
        retention_in_mb   = 35
      }
    }
  }

  # Environment variables
  app_settings = {
    AZURE_STORAGE_ACCOUNT_NAME = var.storage_account_name
  }

  # Managed identity (for the web app to access the storage account)
  identity {
    type = "SystemAssigned"
  }
}

# OpenID Connect credential for GitHub Actions deployment

resource "azuread_application" "lab_entra_app" {
  display_name = "Storage Webapp"
}

output "AZURE_CLIENT_ID" {
  value = azuread_application.lab_entra_app.client_id
}

resource "azuread_service_principal" "lab_service_principal" {
  client_id = azuread_application.lab_entra_app.client_id
}

output "AZURE_TENANT_ID" {
  value = azuread_service_principal.lab_service_principal.application_tenant_id
}

resource "azurerm_role_assignment" "lab_role_assignment" {
  scope                = azurerm_linux_web_app.lab_webapp.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.lab_service_principal.object_id
  principal_type       = "ServicePrincipal"
}

resource "azuread_application_federated_identity_credential" "lab_federated_credential" {
  application_id = azuread_application.lab_entra_app.id
  display_name   = "storage-webapp-deploy"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_username}/${var.github_repo}:ref:refs/heads/main"
}

# Managed identity role assignment

resource "azurerm_role_assignment" "webapp_role_assignment" {
  scope                = azurerm_storage_account.lab_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.lab_webapp.identity[0].principal_id
}
