# Random suffix for unique names
resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get subnets in default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "details" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key concept: create_before_destroy lifecycle
# Security group with create_before_destroy
resource "aws_security_group" "web_sg" {
  name        = "lab4-${local.name_prefix}-web-sg-${random_id.suffix.hex}"
  description = "Security group for web server - Lab 4 Lifecycle Demo"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name        = "lab4-${local.name_prefix}-web-sg"
    Environment = var.environment
  }

  # LIFECYCLE: create_before_destroy
  # Creates new security group before destroying old one
  # Essential for security groups attached to running instances
  lifecycle {
    create_before_destroy = true
  }
}

# Egress rule - separate resource (best practice)
resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "lab4-${local.name_prefix}-egress-all"
  }
}

# Ingress rules using for_each
resource "aws_vpc_security_group_ingress_rule" "rules" {
  for_each = local.ingress_rule_map

  security_group_id = aws_security_group.web_sg.id
  description       = each.value.description
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_blocks[0]

  tags = {
    Name = "lab4-${local.name_prefix}-${each.key}"
  }
}

# Key concept: ignore_changes lifecycle
# EC2 instance with create_before_destroy and ignore_changes
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = local.non_1e_subnets[0]
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name        = local.server_name
    Environment = var.environment
  }

  # LIFECYCLE: Multiple lifecycle settings
  lifecycle {
    # Create new instance before destroying old one (zero-downtime updates)
    create_before_destroy = true

    # LIFECYCLE: ignore_changes
    # Ignore tags that might be modified externally (e.g., by AWS or scripts)
    ignore_changes = [
      tags["LastModifiedBy"],
      tags["aws:autoscaling:groupName"]
    ]
  }
}

# Key concept: prevent_destroy lifecycle
# S3 bucket with prevent_destroy
resource "aws_s3_bucket" "data" {
  bucket = "lab4-${local.name_prefix}-data-${random_id.suffix.hex}"

  tags = {
    Name        = "lab4-${local.name_prefix}-data"
    Critical    = "true"
    Environment = var.environment
  }

  # LIFECYCLE: prevent_destroy
  # Prevents accidental deletion via terraform destroy
  # Must be removed or set to false before you can destroy
  lifecycle {
    prevent_destroy = true
  }
}
