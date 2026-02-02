environment = "staging"

services = ["httpd"]

# Tags for merge() - staging has more tags
common_tags = {
  ManagedBy = "Terraform"
  Team      = "Platform"
}

environment_tags = {
  CostCenter  = "staging"
  Compliance  = "required"
  BackupLevel = "daily"
}

# Security group rules - staging has more rule groups to flatten
security_group_rules = [
  {
    name        = "web"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ports       = [80, 443]
  },
  {
    name        = "db"
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    ports       = [3306, 5432]
  }
]

# For zipmap()
tiers        = ["web", "db"]
server_types = ["t3.nano", "t3.micro"]
