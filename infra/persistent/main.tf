terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "region" {
  type    = string
  default = "eastus2"
}

variable "prefix" {
  type    = string
  default = "delearn"
}

# Persistent resource group — survives workspace teardown
resource "azurerm_resource_group" "persistent" {
  name     = "rg-${var.prefix}-persistent"
  location = var.region
}

# ADLS Gen2 storage account
resource "azurerm_storage_account" "this" {
  name                     = "sa${var.prefix}new0001" # globally unique, no dashes
  resource_group_name      = azurerm_resource_group.persistent.name
  location                 = azurerm_resource_group.persistent.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true # hierarchical namespace = ADLS Gen2
}

resource "azurerm_storage_container" "lakehouse" {
  name                  = "lakehouse"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# Access Connector — managed identity Unity Catalog uses to reach storage
resource "azurerm_databricks_access_connector" "this" {
  name                = "ac-${var.prefix}-dev"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "connector_storage" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}

# ---------- Outputs consumed by the workspace state ----------
output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "container_name" {
  value = azurerm_storage_container.lakehouse.name
}

output "access_connector_id" {
  value = azurerm_databricks_access_connector.this.id
}

output "persistent_rg_name" {
  value = azurerm_resource_group.persistent.name
}
