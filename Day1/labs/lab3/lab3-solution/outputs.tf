output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.web.public_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.web_sg.id
}

output "server_name" {
  description = "Server name created using interpolation"
  value       = local.server_name
}

output "formatted_server_name" {
  description = "Server name with zero-padding using format()"
  value       = local.formatted_server_name
}

output "flattened_rules" {
  description = "Security group rules flattened from nested structure"
  value       = local.flattened_rules
}

output "ingress_rule_map" {
  description = "Flattened rules converted to map for for_each"
  value       = local.ingress_rule_map
}

output "tier_instance_types" {
  description = "Tier to instance type mapping created using zipmap()"
  value       = local.tier_instance_types
}

output "all_tags" {
  description = "All tags merged from common_tags, environment_tags, and resource tags"
  value       = local.all_tags
}

output "user_data_preview" {
  description = "Preview of rendered user_data (first 500 chars)"
  value       = substr(local.user_data, 0, 500)
}
