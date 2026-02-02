variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "project" {
  description = "Use userX format, replace X with your user number. Uncomment default to avoid prompt."
  type        = string
  # default     = "userX"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "services" {
  description = "List of services to enable on the instance"
  type        = list(string)
  default     = ["httpd"]
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Team      = "Platform"
  }
}

variable "environment_tags" {
  description = "Environment-specific tags"
  type        = map(string)
  default     = {}
}

variable "security_group_rules" {
  description = "Nested security group rules - will be flattened for resource creation"
  type = list(object({
    name        = string
    protocol    = string
    cidr_blocks = list(string)
    ports       = list(number)
  }))
  default = [
    {
      name        = "web"
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      ports       = [80, 443]
    }
  ]
}

variable "tiers" {
  description = "List of tiers"
  type        = list(string)
  default     = ["web", "db"]
}

variable "server_types" {
  description = "List of instance types corresponding to tiers"
  type        = list(string)
  default     = ["t3.nano", "t3.micro"]
}
