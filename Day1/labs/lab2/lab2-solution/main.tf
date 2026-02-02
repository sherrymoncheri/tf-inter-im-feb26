# Get the latest Amazon Linux 2023 AMI
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

# Key pattern: for_each with local set creates one SG per unique tier
resource "aws_security_group" "tier_sg" {
  for_each = local.server_tiers

  name        = "${local.name_prefix}-${each.key}-sg"
  description = "Security group for ${each.key} servers"

  tags = {
    Name = "${local.name_prefix}-${each.key}-sg"
    Tier = each.key
  }
}

# Key pattern: for_each over resource collection for related rules
resource "aws_vpc_security_group_egress_rule" "allow_all" {
  for_each = aws_security_group.tier_sg

  security_group_id = each.value.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-${each.key}-egress-all"
  }
}

# Key pattern: conditional count with contains() for tier-specific rules
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  count = contains(local.server_tiers, "web") ? 1 : 0

  security_group_id = aws_security_group.tier_sg["web"].id
  description       = "HTTP"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-web-http"
  }
}

# Database server ingress rule - MySQL (restricted to internal network)
resource "aws_vpc_security_group_ingress_rule" "db_mysql" {
  count = contains(local.server_tiers, "db") ? 1 : 0

  security_group_id = aws_security_group.tier_sg["db"].id
  description       = "MySQL"
  from_port         = 3306
  to_port           = 3306
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/8"

  tags = {
    Name = "${local.name_prefix}-db-mysql"
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ec2-role"
  }
}

# Instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "${local.name_prefix}-ec2-profile"
  }
}

# Key pattern: for_each with map of objects - each.key is server name, each.value is config
resource "aws_instance" "servers" {
  for_each = var.servers

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = each.value.instance_type
  vpc_security_group_ids = [aws_security_group.tier_sg[each.value.tier].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "${local.name_prefix}-${each.key}"
    Tier = each.value.tier
  }
}
