data "azurerm_subscription" "primary" {}

resource "azurerm_resource_group" "db" {
  name     = "${upper(var.region_prefix)}-Database1"
  location = var.region

  tags = local.common_tags
}

resource "azurerm_mssql_server" "mssql_server" {
  name                         = "${lower(var.region_prefix)}-sqlserver"
  resource_group_name          = azurerm_resource_group.db.name
  location                     = azurerm_resource_group.db.location
  version                      = "12.0"
  administrator_login          = var.mssql_server_administrator_login
  administrator_login_password = var.mssql_server_administrator_login_password
  minimum_tls_version          = "1.2"

  azuread_administrator {
    login_username = var.mssql_server_azuread_administrator_login
    object_id      = var.mssql_server_azuread_administrator_objectid
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_mssql_virtual_network_rule" "mssql_vnet_rule_1" {
  name      = "${var.region_prefix}-vnet1-subnet1-rule1"
  server_id = azurerm_mssql_server.mssql_server.id
  subnet_id = lookup(module.vnet1.vnet_subnets_name_id, "${var.region_prefix}-vnet1-subnet1")
}

resource "azurerm_mssql_virtual_network_rule" "mssql_vnet_rule_2" {
  name      = "${var.region_prefix}-vnet1-subnet2-rule2"
  server_id = azurerm_mssql_server.mssql_server.id
  subnet_id = lookup(module.vnet1.vnet_subnets_name_id, "${var.region_prefix}-vnet1-subnet2")
}

resource "azurerm_mssql_virtual_network_rule" "mssql_vnet_rule_3" {
  name      = "${var.region_prefix}-vnet2-subnet1-rule3"
  server_id = azurerm_mssql_server.mssql_server.id
  subnet_id = lookup(module.vnet2.vnet_subnets_name_id, "${var.region_prefix}-vnet2-subnet1")
}

resource "azurerm_mssql_firewall_rule" "mssql_firewall_rule_1" {
  name             = "AWS_DB_Server_10_50_2_87"
  server_id        = azurerm_mssql_server.mssql_server.id
  start_ip_address = "34.233.199.193"
  end_ip_address   = "34.233.199.193"
}

resource "azurerm_mssql_firewall_rule" "mssql_firewall_rule_2" {
  name             = "NordLayer India"
  server_id        = azurerm_mssql_server.mssql_server.id
  start_ip_address = "165.231.251.60"
  end_ip_address   = "165.231.251.60"
}

resource "azurerm_mssql_firewall_rule" "mssql_firewall_rule_3" {
  name             = "NordLayer-USA"
  server_id        = azurerm_mssql_server.mssql_server.id
  start_ip_address = "146.70.93.187"
  end_ip_address   = "146.70.93.187"
}

resource "azurerm_mssql_firewall_rule" "mssql_firewall_rule_4" {
  name             = "AllowAzureService"
  server_id        = azurerm_mssql_server.mssql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}


resource "azapi_update_resource" "mssql_database_autotuning_create_index" {
  type        = "Microsoft.Sql/servers/advisors@2014-04-01"
  resource_id = "${azurerm_mssql_server.mssql_server.id}/advisors/CreateIndex"
  body = jsonencode({
    properties : {
      autoExecuteValue : "Enabled"
    }
  })
  depends_on = [
    azurerm_mssql_server.mssql_server
  ]
}

resource "azapi_update_resource" "mssql_database_autotuning_force_last_good_plan" {
  type        = "Microsoft.Sql/servers/advisors@2014-04-01"
  resource_id = "${azurerm_mssql_server.mssql_server.id}/advisors/ForceLastGoodPlan"
  body = jsonencode({
    properties : {
      autoExecuteValue : "Enabled"
    }
  })
  depends_on = [
    azurerm_mssql_server.mssql_server, azapi_update_resource.mssql_database_autotuning_create_index
  ]
}

resource "azapi_update_resource" "mssql_database_autotuning_drop_index" {
  type        = "Microsoft.Sql/servers/advisors@2014-04-01"
  resource_id = "${azurerm_mssql_server.mssql_server.id}/advisors/DropIndex"
  body = jsonencode({
    properties : {
      autoExecuteValue : "Enabled"
    }
  })
  depends_on = [
    azurerm_mssql_server.mssql_server, azapi_update_resource.mssql_database_autotuning_force_last_good_plan
  ]
}

resource "azapi_update_resource" "mssql_database_vulnerability_assessments" {
  type      = "Microsoft.Sql/servers/sqlVulnerabilityAssessments@2022-05-01-preview"
  name      = "default"
  parent_id = azurerm_mssql_server.mssql_server.id
  body = jsonencode({
    properties = {
      state = "Enabled"
    }
  })
}

resource "azurerm_role_assignment" "storage_role_assignment_mssql_server" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_mssql_server.mssql_server.identity[0].principal_id
}

resource "azurerm_mssql_server_extended_auditing_policy" "mssql_server_audit" {
  server_id              = azurerm_mssql_server.mssql_server.id
  storage_endpoint       = azurerm_storage_account.storage_account1.primary_blob_endpoint
  retention_in_days      = 90
  log_monitoring_enabled = false

  storage_account_subscription_id = data.azurerm_subscription.primary.subscription_id

  depends_on = [
    azurerm_role_assignment.storage_role_assignment_mssql_server,
    azurerm_storage_account.storage_account1,
  ]
}

resource "azurerm_mssql_elasticpool" "elasticpool" {
  name                = "${var.region_prefix}-sqlserver-pool"
  resource_group_name = azurerm_resource_group.db.name
  location            = azurerm_resource_group.db.location
  server_name         = azurerm_mssql_server.mssql_server.name
  max_size_gb         = "200"
  zone_redundant      = true

  sku {
    name     = "GP_Gen5"
    tier     = "GeneralPurpose"
    capacity = 6
    family   = "Gen5"
  }
  per_database_settings {
    min_capacity = 0
    max_capacity = 6
  }

  tags = local.common_tags
}

resource "azurerm_mssql_database" "database1" {
  name            = "${var.region_prefix}-database1"
  server_id       = azurerm_mssql_server.mssql_server.id
  collation       = "SQL_Latin1_General_CP1_CI_AS"
  elastic_pool_id = azurerm_mssql_elasticpool.elasticpool.id

  tags = local.common_tags
}

resource "azurerm_monitor_action_group" "db" {
  name                = "${var.region_prefix}-db-alerts"
  resource_group_name = azurerm_resource_group.db.name
  short_name          = "${upper(var.region_prefix)} DB Alerts"

  azure_app_push_receiver {
    name          = "${upper(var.region_prefix)} DB Notification"
    email_address = "devops@axerosolutions.com"
  }
  email_receiver {
    name          = "${upper(var.region_prefix)} Axero DB Notification"
    email_address = "devops@axerosolutions.com"
  }
  # sms_receiver {
  #   name         = "${upper(var.region_prefix)} SMS DB Notification"
  #   country_code = "1"
  #   phone_number = "8139435797"
  # }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "db_metric_alert" {
  name                     = "${var.region_prefix}-db-metric-alert"
  resource_group_name      = azurerm_resource_group.db.name
  scopes                   = [azurerm_mssql_database.database1.id]
  description              = "Action will be triggered when cpu, storage and disk percent over threshold"
  severity                 = "1"
  target_resource_type     = "Microsoft.Sql/servers/databases"
  target_resource_location = azurerm_resource_group.db.location

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "physical_data_read_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.db.id
  }

  tags = local.common_tags
}