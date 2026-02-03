variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)

  default = {
    Environment = "dev"
    Owner       = "DevOps-Team"
    Project     = "Terraform-Lab"
  }
}

variable "env" {
  default = "dev"
}

variable "project" {
  default = "proj1"
}