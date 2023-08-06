resource "azurerm_resource_group" "gateway" {
  name     = "${upper(var.region_prefix)}-Gateway1"
  location = var.region

  tags = local.common_tags
}

resource "azurerm_public_ip" "gateway_public_ip" {
  name                = "${var.region_prefix}-gateway-public-ip"
  resource_group_name = azurerm_resource_group.gateway.name
  location            = azurerm_resource_group.gateway.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [1, 2, 3]

  tags = local.common_tags
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${module.vnet1.vnet_name}-beap"
  frontend_port_name             = "${module.vnet1.vnet_name}-feport"
  frontend_ip_configuration_name = "${module.vnet1.vnet_name}-feip"
  http_setting_name              = "${module.vnet1.vnet_name}-be-htst"
  listener_name                  = "${module.vnet1.vnet_name}-httplstn"
  request_routing_rule_name      = "${module.vnet1.vnet_name}-rqrt"
  # redirect_configuration_name    = "${module.vnet1.vnet_name}-rdrcfg"
}

resource "azurerm_application_gateway" "apgw" {
  name                = "${var.region_prefix}-appgateway"
  resource_group_name = azurerm_resource_group.gateway.name
  location            = azurerm_resource_group.gateway.location

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
    # capacity = 2
  }

  zones = [1, 2]

  gateway_ip_configuration {
    name      = "${var.region_prefix}-gateway-ip-config"
    subnet_id = lookup(module.vnet1.vnet_subnets_name_id, "${var.region_prefix}-vnet1-gateway")
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.gateway_public_ip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 1
  }

  force_firewall_policy_association = true
  firewall_policy_id                = azurerm_web_application_firewall_policy.apgw_waf_policy.id

  autoscale_configuration {
    min_capacity = 2
    max_capacity = 10
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  tags = local.common_tags
}

resource "azurerm_web_application_firewall_policy" "apgw_waf_policy" {
  name                = "${var.region_prefix}-ap-wafpolicy"
  resource_group_name = azurerm_resource_group.gateway.name
  location            = azurerm_resource_group.gateway.location

  custom_rules {
    name      = "AllowTeamCityIP"
    priority  = 1
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["34.233.199.193/32"]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "NETWebForms"
    priority  = 2
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }

      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values       = ["webresource.axd", "scriptresource.axd", "communifire.idea.js"]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "WopiURLExceptions"
    priority  = 3
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }

      operator           = "Contains"
      negation_condition = false
      match_values       = ["/wopi/files/"]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "MarketingCampaigns"
    priority  = 4
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "QueryString"
      }

      operator           = "Contains"
      negation_condition = false
      match_values       = ["utm_campaign", "utm_medium"]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "Bots"
    priority  = 5
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "UserAgent"
      }

      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values       = ["petalbot"]
    }

    action = "Block"
  }

  custom_rules {
    name      = "AllowCallsToLicenceCheck"
    priority  = 6
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }

      operator           = "Contains"
      negation_condition = false
      match_values       = ["license_check.aspx"]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "InvalidLicenseRule"
    priority  = 7
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }

      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values       = ["license_check.aspx"]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "WikiPageHowToMakeAnAnnouncement"
    priority  = 8
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }

      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values       = ["/how-to-make-an-announcement"]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "resourceKeysCSV"
    priority  = 9
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "QueryString"
      }

      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values       = ["resourcekeyscsv"]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "LoginReturnURL"
    priority  = 10
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }

      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values       = ["/login?"]
    }

    action = "Allow"
  }

  policy_settings {
    enabled            = true
    mode               = "Prevention"
    request_body_check = false
  }

  managed_rules {
    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "connectionData"
      selector_match_operator = "Equals"
    }
    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "resourceKeysCSV"
      selector_match_operator = "Equals"
    }
    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "transport"
      selector_match_operator = "Equals"
    }
    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "utm_medium"
      selector_match_operator = "Equals"
    }
    exclusion {
      match_variable          = "RequestHeaderValues"
      selector                = "/api/scim/v2/Users"
      selector_match_operator = "Contains"
    }
    exclusion {
      match_variable          = "RequestHeaderValues"
      selector                = "webSockets"
      selector_match_operator = "Equals"
    }

    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "0.1"
    }

    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
      rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rule {
          id      = "920300"
          enabled = true
          action  = "Log"
        }

        rule {
          id      = "920440"
          enabled = true
          action  = "Block"
        }
      }
    }

    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "externalURL"
      selector_match_operator = "Equals"
      excluded_rule_set {
        type    = "OWASP"
        version = "3.2"
        rule_group {
          rule_group_name = "REQUEST-931-APPLICATION-ATTACK-RFI"
          excluded_rules  = ["931130"]
        }
      }
    }

    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "keyword"
      selector_match_operator = "Equals"
      excluded_rule_set {
        type    = "OWASP"
        version = "3.2"
        rule_group {
          rule_group_name = "REQUEST-932-APPLICATION-ATTACK-RCE"
          excluded_rules  = ["932150"]
        }

        rule_group {
          rule_group_name = "REQUEST-942-APPLICATION-ATTACK-SQLI"
          excluded_rules  = ["942110"]
        }
      }
    }

    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "singleLogoutServiceUrl"
      selector_match_operator = "Equals"
      excluded_rule_set {
        type    = "OWASP"
        version = "3.2"
        rule_group {
          rule_group_name = "REQUEST-931-APPLICATION-ATTACK-RFI"
          excluded_rules  = ["931130"]
        }
      }
    }

    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "singleSignOnServiceUrl"
      selector_match_operator = "Equals"
      excluded_rule_set {
        type    = "OWASP"
        version = "3.2"
        rule_group {
          rule_group_name = "REQUEST-931-APPLICATION-ATTACK-RFI"
          excluded_rules  = ["931130"]
        }
      }
    }
  }

  tags = local.common_tags
}
