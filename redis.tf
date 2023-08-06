resource "azurerm_resource_group" "redis" {
  name     = "${upper(var.region_prefix)}-Redis1"
  location = var.region

  tags = local.common_tags
}

resource "azurerm_private_dns_zone" "redis_private_dns_zone" {
  name                = var.redis_private_dns_zone_name
  resource_group_name = azurerm_resource_group.redis.name

  tags = local.common_tags
}

resource "azurerm_redis_cache" "redis_cache" {
  name                          = "${lower(var.region_prefix)}-axero-redis"
  location                      = azurerm_resource_group.redis.location
  resource_group_name           = azurerm_resource_group.redis.name
  capacity                      = 1
  family                        = "C"
  sku_name                      = "Standard"
  enable_non_ssl_port           = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  redis_configuration {}
}

resource "azurerm_private_dns_a_record" "redis_record1" {
  name                = azurerm_redis_cache.redis_cache.hostname
  zone_name           = azurerm_private_dns_zone.redis_private_dns_zone.name
  resource_group_name = azurerm_resource_group.redis.name
  ttl                 = 10
  records             = ["192.168.251.100"]

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis_private_vnet1_link" {
  name                  = "${var.region_prefix}-redis-private-private-dns-zone-vnet-link"
  resource_group_name   = azurerm_resource_group.redis.name
  private_dns_zone_name = azurerm_private_dns_zone.redis_private_dns_zone.name
  virtual_network_id    = module.vnet1.vnet_id

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "redis_private_dns_endpoint" {
  name                = "${var.region_prefix}-redis-private-endpoint"
  resource_group_name = azurerm_resource_group.redis.name
  location            = azurerm_resource_group.redis.location
  subnet_id           = lookup(module.vnet1.vnet_subnets_name_id, "${var.region_prefix}-vnet1-subnet2")

  private_service_connection {
    name                           = "${var.region_prefix}-redis-vnet1-private-service-connection"
    private_connection_resource_id = azurerm_redis_cache.redis_cache.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.region_prefix}-redis-private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis_private_dns_zone.id]
  }

  ip_configuration {
    name               = "${var.region_prefix}-redis-private-dns-endpoint-ip-config"
    private_ip_address = "192.168.251.100"
    subresource_name   = "redisCache"
  }

  tags = local.common_tags
}