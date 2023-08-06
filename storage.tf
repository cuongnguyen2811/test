resource "azurerm_resource_group" "storage" {
  name     = "${upper(var.region_prefix)}-Storage1"
  location = var.region

  tags = local.common_tags
}

resource "azurerm_storage_account" "storage_account1" {
  name                              = "${lower(var.region_prefix)}0storageaccount1"
  resource_group_name               = azurerm_resource_group.storage.name
  location                          = azurerm_resource_group.storage.location
  min_tls_version                   = "TLS1_2"
  account_tier                      = "Standard"
  account_replication_type          = "RAGZRS"
  infrastructure_encryption_enabled = true
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = ["146.70.93.187", "34.197.118.194", "34.233.199.193", "20.57.73.241", "40.84.172.16"]
    virtual_network_subnet_ids = [lookup(module.vnet1.vnet_subnets_name_id, "${var.region_prefix}-vnet1-subnet1")]
  }

  blob_properties {
    delete_retention_policy {
      days = 95
    }
    restore_policy {
      days = 90
    }
    versioning_enabled  = true
    change_feed_enabled = true
    container_delete_retention_policy {
      days = 7
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_data_protection_backup_vault" "data_protection_backup_vault" {
  name                = "${var.region_prefix}-data-protection-backup-vault"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  datastore_type      = "VaultStore"
  redundancy          = "GeoRedundant"

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "backup_vault_role_assignment" {
  scope                = azurerm_storage_account.storage_account1.id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = azurerm_data_protection_backup_vault.data_protection_backup_vault.identity[0].principal_id
}

resource "azurerm_data_protection_backup_policy_blob_storage" "backup_policy_blob_storage" {
  name               = "${var.region_prefix}-website-assets"
  vault_id           = azurerm_data_protection_backup_vault.data_protection_backup_vault.id
  retention_duration = "P90D"
}

resource "azurerm_data_protection_backup_instance_blob_storage" "backup_instance_blob_storage" {
  name               = "${var.region_prefix}-backup-instance"
  vault_id           = azurerm_data_protection_backup_vault.data_protection_backup_vault.id
  location           = azurerm_resource_group.storage.location
  storage_account_id = azurerm_storage_account.storage_account1.id
  backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_blob_storage.id

  depends_on = [azurerm_role_assignment.backup_vault_role_assignment]
}

resource "azurerm_storage_container" "container" {
  name                  = "container1"
  storage_account_name  = azurerm_storage_account.storage_account1.name
  container_access_type = "private"
}

resource "azurerm_storage_table" "table1" {
  name                 = "SchemasTable"
  storage_account_name = azurerm_storage_account.storage_account1.name
}

resource "azurerm_storage_table" "table2" {
  name                 = "WADDiagnosticInfrastructureLogsTable"
  storage_account_name = azurerm_storage_account.storage_account1.name
}

resource "azurerm_storage_table" "table3" {
  name                 = "WADMetricsExtensionLogsTable"
  storage_account_name = azurerm_storage_account.storage_account1.name
}

resource "azurerm_storage_table" "table4" {
  name                 = "WADMetricsPT1HP10DV2S20230529"
  storage_account_name = azurerm_storage_account.storage_account1.name
}

resource "azurerm_storage_table" "table5" {
  name                 = "WADMetricsPT1MP10DV2S20230529"
  storage_account_name = azurerm_storage_account.storage_account1.name
}

resource "azurerm_storage_table" "table6" {
  name                 = "WADPerformanceCountersTable"
  storage_account_name = azurerm_storage_account.storage_account1.name
}

resource "azurerm_storage_table" "table7" {
  name                 = "WADWindowsEventLogsTable"
  storage_account_name = azurerm_storage_account.storage_account1.name
}

resource "azurerm_monitor_action_group" "storage_action_group" {
  name                = "${var.region_prefix}-storage-alerts"
  resource_group_name = azurerm_resource_group.storage.name
  short_name          = "${upper(var.region_prefix)}Storage"

  azure_app_push_receiver {
    name          = "${upper(var.region_prefix)} Storage Notification"
    email_address = "devops@axerosolutions.com"
  }
  email_receiver {
    name          = "${upper(var.region_prefix)} Axero Storage Notification"
    email_address = "devops@axerosolutions.com"
  }
  # sms_receiver {
  #   name         = "${upper(var.region_prefix)} SMS Storage Notification"
  #   country_code = "1"
  #   phone_number = "8139435797"
  # }

  tags = local.common_tags
}

resource "azurerm_monitor_activity_log_alert" "backup_vault_activity_log_alert" {
  name                = "${var.region_prefix}-backupvault-activitylog-alert"
  resource_group_name = azurerm_resource_group.storage.name
  scopes              = [azurerm_resource_group.storage.id]
  description         = "Alert if any administrative operation fails"

  criteria {
    resource_id = azurerm_data_protection_backup_vault.data_protection_backup_vault.id
    category    = "Administrative"
    levels      = ["Critical", "Error"]
    status      = "Failed"
  }

  action {
    action_group_id = azurerm_monitor_action_group.storage_action_group.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "backup_vault_metric_alert" {
  name                     = "${var.region_prefix}-backupvault-metric-alert"
  resource_group_name      = azurerm_resource_group.storage.name
  scopes                   = [azurerm_data_protection_backup_vault.data_protection_backup_vault.id]
  description              = "Action will be triggered when Threshold count is greater than 1."
  severity                 = "1"
  target_resource_type     = "Microsoft.DataProtection/BackupVaults"
  target_resource_location = azurerm_resource_group.storage.location

  criteria {
    metric_namespace = "Microsoft.DataProtection/BackupVaults"
    metric_name      = "BackupHealthEvent"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.storage_action_group.id
  }

  tags = local.common_tags
}

# resource "azapi_resource" "mdc_storage_classic" {
#   type = "Microsoft.Security/pricings@2022-03-01"
#   name = "StorageAccounts"
#   parent_id = data.azurerm_subscription.primary.id
#   body = jsonencode({
#     properties = {
#       pricingTier = "Standard"
#       subPlan = "PerTransaction"
#     }
#   })
# }
