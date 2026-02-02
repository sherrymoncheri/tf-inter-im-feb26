output "server_details" {
  description = "Details of all created servers"
  value = {
    for name, instance in aws_instance.servers : name => {
      id            = instance.id
      private_ip    = instance.private_ip
      tier          = instance.tags["Tier"]
      instance_type = instance.instance_type
    }
  }
}

output "security_groups" {
  description = "Security groups created by tier"
  value = {
    for tier, sg in aws_security_group.tier_sg : tier => {
      id   = sg.id
      name = sg.name
    }
  }
}

output "instance_profile_name" {
  description = "IAM instance profile name"
  value       = aws_iam_instance_profile.ec2_profile.name
}
