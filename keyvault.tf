data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "keyvault" {
  name     = "${upper(var.region_prefix)}-KeyVault1"
  location = var.region

  tags = local.common_tags
}

resource "azurerm_key_vault" "key_vault" {
  name                        = "${lower(var.region_prefix)}-axerokey23072023"
  location                    = azurerm_resource_group.keyvault.location
  resource_group_name         = azurerm_resource_group.keyvault.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  network_acls {
    bypass = "AzureServices"
    default_action = "Deny"
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }

  tags = local.common_tags
}
