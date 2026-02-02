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

# This is the key variable - a map of objects defining our servers
variable "servers" {
  description = "Map of server configurations"
  type = map(object({
    instance_type = string
    tier          = string
  }))
}
