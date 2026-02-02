locals {
  name_prefix = "lab3-${var.project}-${var.environment}"

  # Key concept: simple string joining - use interpolation
  server_name = "${local.name_prefix}-web"

  # Key concept: format() for complex formatting (zero-padding)
  # format("%s-web-%02d", "lab3-user1-dev", 1) -> "lab3-user1-dev-web-01"
  formatted_server_name = format("%s-web-%02d", local.name_prefix, 1)

  # Key concept: templatefile() renders template with variables
  user_data = templatefile("${path.module}/templates/user_data.tftpl", {
    environment = var.environment
    server_name = local.server_name
    project     = var.project
    services    = var.services
  })

  # Key pattern: flatten() converts nested rule groups into flat list for for_each
  # Input: [{name="web", ports=[80,443]}, {name="db", ports=[3306]}]
  # Output: [{name="web", port=80}, {name="web", port=443}, {name="db", port=3306}]
  flattened_rules = flatten([
    for rule in var.security_group_rules : [
      for port in rule.ports : {
        key         = "${rule.name}-${port}"
        name        = rule.name
        port        = port
        protocol    = rule.protocol
        cidr_blocks = rule.cidr_blocks
      }
    ]
  ])

  # Key pattern: convert flattened list to map for for_each
  ingress_rule_map = {
    for rule in local.flattened_rules : rule.key => rule
  }

  # Key concept: zipmap() creates map from two parallel lists
  # zipmap(["web", "db"], ["t3.nano", "t3.micro"]) -> {web = "t3.nano", db = "t3.micro"}
  tier_instance_types = zipmap(var.tiers, var.server_types)

  # Key concept: merge() combines maps (later values override earlier)
  all_tags = merge(
    var.common_tags,
    var.environment_tags,
    {
      Name        = local.server_name
      Environment = var.environment
    }
  )
}
