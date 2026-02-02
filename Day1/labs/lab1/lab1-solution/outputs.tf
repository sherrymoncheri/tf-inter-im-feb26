output "environment" {
  description = "Current environment"
  value       = terraform.workspace
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_type" {
  description = "EC2 instance type (varies by environment)"
  value       = aws_instance.web.instance_type
}

output "root_volume_size" {
  description = "Root volume size in GB"
  value       = aws_instance.web.root_block_device[0].volume_size
}

# Conditional outputs - return null if resource doesn't exist
output "db_instance_id" {
  description = "DB instance ID (null if not created)"
  value       = var.enable_db_instance ? aws_instance.db[0].id : null
}

output "db_private_ip" {
  description = "DB instance private IP (null if not created)"
  value       = var.enable_db_instance ? aws_instance.db[0].private_ip : null
}

output "db_security_group_id" {
  description = "DB security group ID (null if not created)"
  value       = var.enable_db_instance ? aws_security_group.db_sg[0].id : null
}

# Summary of what was created
output "resources_created" {
  description = "Summary of conditionally created resources"
  value = {
    db_instance       = var.enable_db_instance
    db_security_group = var.enable_db_instance
  }
}
# Key pattern: use same condition as resource creation to safely access [0]
