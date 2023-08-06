data "ec_stack" "latest" {
  version_regex = var.elasticcloud_deployment_version
  region        = var.elasticcloud_deployment_region
}

data "azapi_resource" "elastic_privateendpoint_resource_guid" {
  type      = "Microsoft.Network/privateEndpoints@2022-01-01"
  name      = azurerm_private_endpoint.elasticcloud.name
  parent_id = azurerm_resource_group.elasticcloud.id

  response_export_values = ["properties.resourceGuid"]

  depends_on = [
    azurerm_private_endpoint.elasticcloud
  ]
}

resource "azurerm_resource_group" "elasticcloud" {
  name     = "${upper(var.region_prefix)}-ElasticCloud1"
  location = var.region

  tags = local.common_tags
}

resource "azurerm_private_dns_zone" "elasticcloud_private_dns_zone" {
  name                = var.elasticcloud_private_dns_zone_name
  resource_group_name = azurerm_resource_group.elasticcloud.name

  tags = local.common_tags
}

resource "azurerm_private_dns_a_record" "elastic_record1" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.elasticcloud_private_dns_zone.name
  resource_group_name = azurerm_resource_group.elasticcloud.name
  ttl                 = 60
  records             = ["192.168.251.50"]

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "elastic_private_vnet1_link" {
  name                  = "${var.region_prefix}-elastic-private-dns-zone-vnet1-link"
  resource_group_name   = azurerm_resource_group.elasticcloud.name
  private_dns_zone_name = azurerm_private_dns_zone.elasticcloud_private_dns_zone.name
  virtual_network_id    = module.vnet1.vnet_id

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "elasticcloud" {
  name                = "${var.region_prefix}-elasticcloud-private-dns-endpoint"
  resource_group_name = azurerm_resource_group.elasticcloud.name
  location            = azurerm_resource_group.elasticcloud.location
  subnet_id           = lookup(module.vnet1.vnet_subnets_name_id, "${var.region_prefix}-vnet1-subnet2")

  private_service_connection {
    name                              = "${var.region_prefix}-elasticcloud-vnet1-private-service-connection"
    private_connection_resource_alias = var.elasticcloud_privatelink_service_alias
    is_manual_connection              = true
    request_message                   = "Azure Private Connection from ${upper(var.region_prefix)} to ElasticCloud Deployment"
  }

  private_dns_zone_group {
    name                 = "${var.region_prefix}-elasticcloud-private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.elasticcloud_private_dns_zone.id]
  }

  ip_configuration {
    name               = "${var.region_prefix}-elasticcloud-private-dns-endpoint-ip-config"
    private_ip_address = "192.168.251.50"
  }

  tags = local.common_tags
}

# Create an Elastic Cloud deployment
resource "ec_deployment" "ec_deployment1" {
  # Optional name.
  name = "Azure${upper(var.region_prefix)}CloudProd"

  # Mandatory fields
  region                 = var.elasticcloud_deployment_region
  version                = data.ec_stack.latest.version
  deployment_template_id = var.elasticcloud_deployment_template_id

  traffic_filter = [
    ec_deployment_traffic_filter.AzureElasticCloud.id, ec_deployment_traffic_filter.Axero_VPN_India.id, ec_deployment_traffic_filter.Axero_VPN_USA.id
  ]

  # Use the deployment template defaults
  elasticsearch = {
    hot = {
      size          = "4g"
      size_resource = "memory"
      zone_count    = 2
      autoscaling   = {}
    }
  }

  # Initial size for `hot_content` tier is set to 8g
  # so `hot_content`'s size has to be added to the `ignore_changes` meta-argument to ignore future modifications that can be made by the autoscaler
  lifecycle {
    ignore_changes = [
      elasticsearch.hot.size
    ]
  }

  kibana = {}

  integrations_server = {}

  enterprise_search = {}

  tags = local.common_tags
}

resource "ec_deployment_traffic_filter" "AzureElasticCloud" {
  name               = "Azure${upper(var.region_prefix)}CloudProdPrivateLink"
  region             = var.elasticcloud_deployment_region
  type               = "azure_private_endpoint"
  include_by_default = true

  rule {
    azure_endpoint_name = azurerm_private_endpoint.elasticcloud.name
    azure_endpoint_guid = jsondecode(data.azapi_resource.elastic_privateendpoint_resource_guid.output).properties.resourceGuid
  }
}

resource "ec_deployment_traffic_filter" "Axero_VPN_India" {
  name   = "Axero VPN India to ${upper(var.region_prefix)}"
  region = var.elasticcloud_deployment_region
  type   = "ip"

  rule {
    source = "165.231.251.60/32"
  }
}

resource "ec_deployment_traffic_filter" "Axero_VPN_USA" {
  name   = "Axero VPN USA to ${upper(var.region_prefix)}"
  region = var.elasticcloud_deployment_region
  type   = "ip"

  rule {
    source = "146.70.93.187/32"
  }
}