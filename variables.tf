variable "region" {
  type        = string
  description = "Region name"
}

variable "region_prefix" {
  type        = string
  description = "Region prefix name"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "app_service_plan_sku_name" {
  type        = string
  description = "Azure App Service Plan SKU name"
}

variable "mssql_server_administrator_login" {
  type        = string
  description = "Azure SQL Server Administrator's username"
}

variable "mssql_server_administrator_login_password" {
  type        = string
  description = "Azure SQL Server Administrator's password"
}

variable "mssql_server_azuread_administrator_login" {
  type        = string
  description = "Azure AD SQL Server Administrator's username"
}

variable "mssql_server_azuread_administrator_objectid" {
  type        = string
  description = "Azure AD SQL Server Administrator's ObjectID"
}

variable "elasticcloud_deployment_version" {
  type        = string
  description = "ElasticCloud Deployment version"
}

variable "elasticcloud_deployment_region" {
  type        = string
  description = "ElasticCloud Deployment Region"
}

variable "elasticcloud_deployment_template_id" {
  type        = string
  description = "ElasticCloud Template ID"
}

variable "elasticcloud_privatelink_service_alias" {
  type        = string
  description = "ElasticCloud Azure Private Link Service Alias"
}

variable "elasticcloud_private_dns_zone_name" {
  type        = string
  description = "ElasticCloud private DNS Zone link"
}

variable "redis_private_dns_zone_name" {
  type        = string
  description = "Redis private DNS Zone link"
}