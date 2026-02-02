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

# Conditional DB security group - only when enabled
resource "aws_security_group" "db_sg" {
  count = var.enable_db_instance ? 1 : 0

  name        = "${local.name_prefix}-db-sg"
  description = "Security group for database server"

  tags = {
    Name = "${local.name_prefix}-db-sg"
  }
}

# DB ingress rule - allow from web security group only
resource "aws_vpc_security_group_ingress_rule" "db_from_web" {
  count = var.enable_db_instance ? 1 : 0

  security_group_id            = aws_security_group.db_sg[0].id
  description                  = "Allow traffic from web servers"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.web_sg.id

  tags = {
    Name = "${local.name_prefix}-db-from-web"
  }
}

# DB egress rule
resource "aws_vpc_security_group_egress_rule" "db_allow_all" {
  count = var.enable_db_instance ? 1 : 0

  security_group_id = aws_security_group.db_sg[0].id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-db-egress-all"
  }
}

# Conditional DB instance - only when enabled
resource "aws_instance" "db" {
  count = var.enable_db_instance ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.nano"
  vpc_security_group_ids = [aws_security_group.db_sg[0].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "${local.name_prefix}-db"
  }
}

# Security group
resource "aws_security_group" "web_sg" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web server"

  tags = {
    Name = "${local.name_prefix}-web-sg"
  }
}

# Standalone ingress rules (best practice)
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web_sg.id
  description       = "HTTP"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = local.environment == "dev" ? "0.0.0.0/0" : "10.0.0.0/8"

  tags = {
    Name = "${local.name_prefix}-http"
  }
}

# Standalone egress rule
resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-egress-all"
  }
}

# IAM role for EC2
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

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "${local.name_prefix}-ec2-profile"
  }
}

# EC2 instance with environment-based config
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Inline ternary - instance type varies by environment (workspace)
  instance_type = local.environment == "dev" ? "t3.nano" : "t3.micro"

  root_block_device {
    # Ternary - volume size varies by environment (workspace)
    volume_size = local.environment == "staging" ? 20 : 10
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${local.name_prefix}-web"
  }
}
# Key patterns: count for conditional resources, ternary for config values
