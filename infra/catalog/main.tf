terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.60"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "prefix" {
  type    = string
  default = "delearn"
}

variable "workspace_resource_group" {
  type        = string
  description = "Resource group of the currently-live Databricks workspace"
  default     = "rg-delearn-dev"
}

variable "workspace_name" {
  type        = string
  description = "Name of the currently-live Databricks workspace"
  default     = "adb-delearn-dev"
}

variable "storage_account_name" {
  type = string
}

variable "container_name" {
  type    = string
  default = "lakehouse"
}

variable "access_connector_id" {
  type = string
}

# Looks up the live workspace to talk to (must exist at apply time only)
data "azurerm_databricks_workspace" "this" {
  name                = var.workspace_name
  resource_group_name = var.workspace_resource_group
}

provider "databricks" {
  host                        = "https://${data.azurerm_databricks_workspace.this.workspace_url}"
  azure_workspace_resource_id = data.azurerm_databricks_workspace.this.id
}

resource "databricks_storage_credential" "this" {
  name = "cred-${var.prefix}"
  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }
  comment = "Managed by Terraform - persistent"
}

resource "databricks_external_location" "this" {
  name = "ext-${var.prefix}-lakehouse"
  url = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    var.container_name,
    var.storage_account_name
  )
  credential_name = databricks_storage_credential.this.id
  comment          = "Managed by Terraform - persistent"
}

resource "databricks_catalog" "this" {
  name         = "retail_lakehouse"
  comment      = "Retail Sales Lakehouse project catalog"
  storage_root = databricks_external_location.this.url
  properties = {
    purpose = "dp750-practice"
  }
}

resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.this.name
  name         = "bronze"
  comment      = "Raw ingested data"
}

resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.this.name
  name         = "silver"
  comment      = "Cleaned, deduped, schema-enforced data"
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.this.name
  name         = "gold"
  comment      = "Aggregated business-level tables"
}

output "catalog_name" {
  value = databricks_catalog.this.name
}
