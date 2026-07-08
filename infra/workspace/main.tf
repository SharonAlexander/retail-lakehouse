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

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}-dev"
  location = var.region
}

resource "azurerm_databricks_workspace" "this" {
  name                        = "adb-${var.prefix}-dev"
  resource_group_name         = azurerm_resource_group.this.name
  location                    = azurerm_resource_group.this.location
  sku                         = "premium"
  managed_resource_group_name = "rg-${var.prefix}-dev-managed"
}

output "workspace_url" {
  value = "https://${azurerm_databricks_workspace.this.workspace_url}"
}
