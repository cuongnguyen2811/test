output "elasticsearch_endpoint" {
  value = ec_deployment.ec_deployment1.elasticsearch.https_endpoint
}

output "elasticsearch_username" {
  value = ec_deployment.ec_deployment1.elasticsearch_username
}

output "elasticsearch_password" {
  value     = ec_deployment.ec_deployment1.elasticsearch_password
  sensitive = true
}