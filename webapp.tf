data "azurerm_role_definition" "monitoring_contributor" {
  name = "Monitoring Contributor"
}

data "azurerm_role_definition" "monitoring_reader" {
  name = "Monitoring Reader"
}

locals {
  splitArray1             = split("/", data.azurerm_role_definition.monitoring_contributor.id)
  monitoringContributorId = element(local.splitArray1, length(local.splitArray1) - 1)
}

locals {
  splitArray2        = split("/", data.azurerm_role_definition.monitoring_reader.id)
  monitoringReaderId = element(local.splitArray2, length(local.splitArray2) - 1)
}

resource "azurerm_resource_group" "webapp" {
  name     = "${upper(var.region_prefix)}-WebApps1"
  location = var.region

  tags = local.common_tags
}

# resource "azurerm_app_service_environment_v3" "ase3" {
#   name                = "${var.region_prefix}-ase3"
#   resource_group_name = azurerm_resource_group.webapp.name
#   subnet_id           = lookup(module.vnet1.vnet_subnets_name_id, "${var.region_prefix}-vnet1-subnet1")

#   internal_load_balancing_mode = "Web, Publishing"

#   cluster_setting {
#     name  = "DisableTls1.0"
#     value = "1"
#   }

#   # cluster_setting {
#   #   name  = "InternalEncryption"
#   #   value = "true"
#   # }

#   cluster_setting {
#     name  = "FrontEndSSLCipherSuiteOrder"
#     value = "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
#   }

#   tags = local.common_tags
# }

resource "azurerm_service_plan" "asp" {
  name                = "${var.region_prefix}-asp"
  resource_group_name = azurerm_resource_group.webapp.name
  location            = azurerm_resource_group.webapp.location
  os_type             = "Windows"
  sku_name            = "P2v3"
  # app_service_environment_id = azurerm_app_service_environment_v3.ase3.id

  tags = local.common_tags
}

module "vnet1" {
  source              = "Azure/vnet/azurerm"
  version             = "4.1.0"
  vnet_name           = "${var.region_prefix}-vnet1"
  resource_group_name = azurerm_resource_group.webapp.name
  use_for_each        = true
  address_space       = ["192.168.250.0/23", "192.168.252.0/23"]
  subnet_prefixes     = ["192.168.250.0/24", "192.168.251.0/24", "192.168.252.0/24"]
  subnet_names        = ["${var.region_prefix}-vnet1-subnet1", "${var.region_prefix}-vnet1-subnet2", "${var.region_prefix}-vnet1-gateway"]
  vnet_location       = azurerm_resource_group.webapp.location

  subnet_service_endpoints = {
    "${var.region_prefix}-vnet1-subnet1" = ["Microsoft.Sql", "Microsoft.KeyVault", "Microsoft.Storage"],
    "${var.region_prefix}-vnet1-subnet2" = ["Microsoft.Sql", "Microsoft.KeyVault"],
    "${var.region_prefix}-vnet1-gateway" = ["Microsoft.KeyVault"]
  }

  subnet_delegation = {
    "${var.region_prefix}-vnet1-subnet1" = {
      "Microsoft.Web.hostingEnvironments" = {
        service_name    = "Microsoft.Web/hostingEnvironments"
        service_actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }

  subnet_enforce_private_link_endpoint_network_policies = {
    "${var.region_prefix}-vnet1-subnet2" = true
  }

  tags = local.common_tags
}

module "vnet2" {
  source              = "Azure/vnet/azurerm"
  version             = "4.1.0"
  vnet_name           = "${var.region_prefix}-vnet2"
  resource_group_name = azurerm_resource_group.webapp.name
  use_for_each        = true
  address_space       = ["192.168.250.0/23"]
  subnet_prefixes     = ["192.168.250.0/24", "192.168.251.0/24"]
  subnet_names        = ["${var.region_prefix}-vnet2-subnet1", "${var.region_prefix}-vnet2-subnet2"]
  vnet_location       = azurerm_resource_group.webapp.location

  subnet_service_endpoints = {
    "${var.region_prefix}-vnet2-subnet1" = ["Microsoft.Sql", "Microsoft.KeyVault", "Microsoft.Storage"],
    "${var.region_prefix}-vnet2-subnet2" = ["Microsoft.KeyVault"]
  }

  subnet_delegation = {
    "${var.region_prefix}-vnet2-subnet1" = {
      "Microsoft.Web.hostingEnvironments" = {
        service_name    = "Microsoft.Web/hostingEnvironments"
        service_actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }

  tags = local.common_tags
}

# resource "azurerm_private_dns_zone" "webapp" {
#   name                = "${var.region_prefix}-vnet2.appserviceenvironment.net"
#   resource_group_name = azurerm_resource_group.webapp.name

#   tags = local.common_tags
# }

# resource "azurerm_private_dns_a_record" "webapp_record1" {
#   name                = "*"
#   zone_name           = azurerm_private_dns_zone.webapp.name
#   resource_group_name = azurerm_resource_group.webapp.name
#   ttl                 = 3600
#   records             = azurerm_app_service_environment_v3.ase3.internal_inbound_ip_addresses

#   tags = local.common_tags
# }

# resource "azurerm_private_dns_a_record" "webapp_record2" {
#   name                = "@"
#   zone_name           = azurerm_private_dns_zone.webapp.name
#   resource_group_name = azurerm_resource_group.webapp.name
#   ttl                 = 3600
#   records             = azurerm_app_service_environment_v3.ase3.internal_inbound_ip_addresses

#   tags = local.common_tags
# }

# resource "azurerm_private_dns_a_record" "webapp_record3" {
#   name                = "*.scm"
#   zone_name           = azurerm_private_dns_zone.webapp.name
#   resource_group_name = azurerm_resource_group.webapp.name
#   ttl                 = 3600
#   records             = azurerm_app_service_environment_v3.ase3.internal_inbound_ip_addresses

#   tags = local.common_tags
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "vnet2_link" {
#   name                  = "${var.region_prefix}-webapp-private-dns-zone-vnet-link"
#   resource_group_name   = azurerm_resource_group.webapp.name
#   private_dns_zone_name = azurerm_private_dns_zone.webapp.name
#   virtual_network_id    = module.vnet2.vnet_id

#   tags = local.common_tags
# }

resource "azurerm_windows_web_app" "webapp1" {
  name                = "${var.region_prefix}-axero-webapp1"
  resource_group_name = azurerm_resource_group.webapp.name
  location            = azurerm_resource_group.webapp.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {}

  tags = local.common_tags
}

resource "azurerm_monitor_action_group" "webapp" {
  name                = "${var.region_prefix}-webapp-alerts"
  resource_group_name = azurerm_resource_group.webapp.name
  short_name          = "${upper(var.region_prefix)}WebAlerts"

  azure_app_push_receiver {
    name          = "${upper(var.region_prefix)} WebApp Notification"
    email_address = "devops@axerosolutions.com"
  }
  email_receiver {
    name          = "${upper(var.region_prefix)} Axero WebApp Notification"
    email_address = "devops@axerosolutions.com"
  }
  # sms_receiver {
  #   name         = "${upper(var.region_prefix)} SMS WebApp Notification"
  #   country_code = "1"
  #   phone_number = "8139435797"
  # }

  tags = local.common_tags
}

resource "azurerm_monitor_action_group" "webapp_insight_action_group" {
  name                = "${var.region_prefix}-insight-smart-detect"
  resource_group_name = azurerm_resource_group.webapp.name
  short_name          = "${upper(var.region_prefix)}Insight"

  arm_role_receiver {
    name    = "Monitoring Contributor"
    role_id = local.monitoringContributorId
  }
  arm_role_receiver {
    name    = "Monitoring Reader"
    role_id = local.monitoringReaderId
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "appservice_metric_alert" {
  name                     = "${var.region_prefix}-appservice-metric-alert"
  resource_group_name      = azurerm_resource_group.webapp.name
  scopes                   = [azurerm_service_plan.asp.id]
  description              = "Action will be triggered when cpu and memory percent over threshold"
  severity                 = "2"
  target_resource_type     = "Microsoft.Web/serverfarms"
  target_resource_location = azurerm_resource_group.webapp.location

  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "Cpupercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "Memorypercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.webapp.id
  }

  tags = local.common_tags
}
