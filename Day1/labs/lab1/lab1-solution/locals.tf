locals {
  # Environment derived from workspace - single source of truth
  environment = terraform.workspace
  name_prefix = "lab1-${var.project}-${local.environment}"
  # Key concept: environment derived from workspace
}
