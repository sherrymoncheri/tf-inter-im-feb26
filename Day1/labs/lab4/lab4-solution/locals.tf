locals {
  # Common prefix for all resources
  name_prefix = "${var.project}-${var.environment}"

  # Server name
  server_name = "lab4-${local.name_prefix}-web"

  # Transform ingress_rules list into map for for_each
  ingress_rule_map = {
    for rule in var.ingress_rules :
    format("%s-%d", rule.protocol, rule.port) => rule
  }
}
