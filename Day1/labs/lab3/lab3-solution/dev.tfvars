environment = "dev"

services = ["httpd"]

# Tags for merge()
common_tags = {
  ManagedBy = "Terraform"
  Team      = "Platform"
}

environment_tags = {
  CostCenter = "development"
}

# Security group rules - nested structure that gets flattened
security_group_rules = [
  {
    name        = "web"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ports       = [80, 443]
  }
]

# For zipmap()
tiers        = ["web", "db"]
server_types = ["t3.nano", "t3.micro"]
