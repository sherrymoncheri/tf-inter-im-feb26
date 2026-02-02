output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.web.public_ip
}

output "server_name" {
  description = "Server name"
  value       = local.server_name
}

output "security_group_id" {
  description = "Security group ID (has create_before_destroy)"
  value       = aws_security_group.web_sg.id
}

output "data_bucket_name" {
  description = "Data S3 bucket name (protected by prevent_destroy)"
  value       = aws_s3_bucket.data.id
}

output "lifecycle_info" {
  description = "Summary of lifecycle configurations in this lab"
  value = {
    security_group = {
      resource = "aws_security_group.web_sg"
      lifecycle = {
        create_before_destroy = true
      }
      reason = "Essential for security groups attached to running instances"
    }
    ec2_instance = {
      resource = "aws_instance.web"
      lifecycle = {
        create_before_destroy = true
        ignore_changes        = ["tags[\"LastModifiedBy\"]", "tags[\"aws:autoscaling:groupName\"]"]
      }
      reason = "Zero-downtime updates and ignore external tag modifications"
    }
    data_bucket = {
      resource = "aws_s3_bucket.data"
      lifecycle = {
        prevent_destroy = true
      }
      reason = "Protect critical data from accidental deletion"
    }
  }
}
