# Required providers
terraform {
  required_version = ">= 1.3.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.66.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "1.8.0"
    }
    ec = {
      source  = "elastic/ec"
      version = "0.6.0"
    }
  }
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "tfstatefrancecentral01"
  #   container_name       = "eu-tfstate"
  #   key                  = "terraform.tfstate"
  # }
}

# Azure RM provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # client_id       = "${ARM_CLIENT_ID}"
  # client_secret   = "${ARM_CLIENT_SECRET}"
  # tenant_id       = "${ARM_TENANT_ID}"
  # subscription_id = "${ARM_SUBSCRIPTION_ID}"
}

# Elastic Cloud providers
provider "ec" {
  # apikey = "${EC_API_KEY}"
}