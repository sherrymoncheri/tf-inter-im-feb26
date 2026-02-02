locals {
  environment = terraform.workspace

  # Name prefix for all resources
  name_prefix = "lab2-${var.project}-${local.environment}"

  # Key concept: extracting unique values using for expression and toset()
  server_tiers = toset([for server in var.servers : server.tier])
}
