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

# Feature flag - boolean switch to enable/disable optional DB instance
variable "enable_db_instance" {
  description = "Enable optional database EC2 instance"
  type        = bool
  default     = false
}

