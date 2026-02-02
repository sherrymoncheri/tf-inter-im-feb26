# Lab 1: Conditional Resource Creation

## Environment-Based Infrastructure with count and Ternary Operators

---

## Objective

Learn to create resources conditionally based on environment and feature flags. You'll use `count` to toggle resource creation (0 or 1) and ternary operators to select configuration values based on conditions.

---

## Time Estimate

**30-35 minutes**

---

## What You'll Learn

- Using `count` for conditional resource creation (create or skip)
- Ternary operators for inline configuration selection
- Feature flags pattern for optional resources
- Security group reference pattern (`referenced_security_group_id`)
- Conditional outputs using ternary expressions
- Using `terraform.workspace` for environment-based configuration

---

## High-Level Instructions

1. Create project structure with workspaces and feature flag variables
2. Implement conditional DB instance with security group using `count`
3. Use inline ternary operators for environment-based instance sizing
4. Create conditional outputs using ternary expressions
5. Test with different workspaces (dev, staging) and feature flags
6. Clean up resources

---

## Detailed Instructions

### Step 1: Create Your Working Directory

```bash
cd ~
mkdir -p lab1-im
cd lab1-im
```

---

### Step 2: Create Terraform Configuration

**Copy `terraform.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab1/lab1-solution/terraform.tf .
```

```hcl
terraform {
  required_version = "~> 1.13.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.20.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      owner  = var.project
      Course = "Terraform-Intermediate"
      Lab    = "lab1"
    }
  }
}
```

---

### Step 3: Create Variables File

**Copy `variables.tf` from the solution directory:**

```bash
cp ~/intermediate/day1/labs/lab1/lab1-solution/variables.tf .
```

After copying, the file contains:

```hcl
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
```

> **Action Required:** Edit `variables.tf` to uncomment the `default` line for the `project` variable and replace `X` with your assigned user number. To uncomment, remove the `#` at the beginning of the line (e.g., change `# default = "userX"` to `default = "user3"` if you are user 3).

**Note:** We don't need an `environment` variable because we'll derive it from `terraform.workspace`.

---

### Step 4: Create Locals File

**Copy `locals.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab1/lab1-solution/locals.tf .
```

```hcl
locals {
  # Environment derived from workspace - single source of truth
  environment = terraform.workspace
  name_prefix = "lab1-${var.project}-${local.environment}"
  # Key concept: environment derived from workspace
}
```

**Key concept:** Using `terraform.workspace` ensures the environment is always consistent with the active workspace. This prevents mismatches where you might accidentally apply dev settings to a staging workspace.

---

### Step 5: Create Main Configuration

**Copy `main.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab1/lab1-solution/main.tf .
```

```hcl
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

# Security group for web server
resource "aws_security_group" "web_sg" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web server"

  tags = {
    Name = "${local.name_prefix}-web-sg"
  }
}

# Standalone ingress rules
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
```

**Key patterns in this file:**

1. **`count = var.enable_db_instance ? 1 : 0`** - Conditional resource creation (DB instance, security group, and rules)
2. **Inline ternary operators** - Used directly in resource attributes for single-use values
3. **Security group reference** - `referenced_security_group_id` allows traffic only from the web security group
4. **Dependent conditional resources** - DB SG, rules, and instance all use the same count condition

---

### Step 6: Create Outputs File

**Copy `outputs.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab1/lab1-solution/outputs.tf .
```

```hcl
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
```

**Key output pattern:**
- `var.enable_db_instance ? aws_instance.db[0].id : null` - Use the same condition that controls resource creation to safely access it or return null

---

### Step 7: Create Feature Flag Variable Files

The tfvars files only contain feature flags. The environment is automatically derived from the workspace name.

**Copy `dev.tfvars` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab1/lab1-solution/dev.tfvars .
```

```hcl
# Feature flag - no DB instance in dev
enable_db_instance = false
```

**Copy `staging.tfvars` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab1/lab1-solution/staging.tfvars .
```

```hcl
# Feature flag - enable DB instance for staging
enable_db_instance = true
```

---

### Step 8: Initialize the Dev Environment

```bash
# Initialize Terraform
terraform init

# Validate
terraform validate

# Create dev workspace
terraform workspace new dev

# Plan with dev environment
terraform plan -var-file="dev.tfvars"

# Apply with dev environment
terraform apply -var-file="dev.tfvars"
```

Review resources created in Dev environment:
```bash
# 1. Verify EC2 instance
terraform output instance_id
terraform output instance_type

# 2. Check conditional resources
terraform output resources_created

# 3. Verify DB instance doesn't exist in dev
terraform output db_instance_id

#│ Error: Output "db_instance_id" not found
```

### Step 9: Test Staging Environment

Now let's see how staging differs:

```bash
# Create staging workspace
terraform workspace new staging

# Plan with staging
terraform plan -var-file="staging.tfvars"

# Apply with staging environment
terraform apply -var-file="staging.tfvars"
```
Review resources created in Staging environment:
```bash
# 1. Verify EC2 instance
terraform output instance_id
terraform output instance_type

# 2. Check conditional resources
terraform output resources_created

# 3. Verify DB instance should exist in Staging environment
terraform output db_instance_id
```
---

### Step 10: Test Feature Flag Override

First, let's deploy dev. Switch to the dev workspace and apply:

```bash
# Switch to dev workspace
terraform workspace select dev
```

You can override feature flags on the command line:

```bash
terraform plan -var-file="dev.tfvars" -var="enable_db_instance=true"
```

Notice that the DB instance would be created even though we're using dev.tfvars that sets enable_db_instance to false.

This demonstrates the **feature flag pattern** - you can selectively turn on/off features independently of the environment.

---

## Key Concepts Recap

### Conditional Resource Creation with count

```hcl
resource "aws_instance" "db" {
  count = var.enable_db_instance ? 1 : 0  # Create only when enabled
  # ...
}
```

- `count = 1` creates the resource
- `count = 0` skips creation entirely

### Ternary Operators (Inline)

```hcl
# Simple ternary - use inline for single-use values
instance_type = local.environment == "dev" ? "t3.nano" : "t3.micro"

# Another ternary example
volume_size = local.environment == "staging" ? 20 : 10
```

### Using terraform.workspace

```hcl
locals {
  environment = terraform.workspace  # "dev" or "staging"
  name_prefix = "${var.project}-${local.environment}"
}
```

### Handling Conditional Outputs

```hcl
# Use the same condition as the resource to safely access or return null
output "db_instance_id" {
  value = var.enable_db_instance ? aws_instance.db[0].id : null
}
```

By using the same condition (`var.enable_db_instance`) that controls resource creation, you can safely access `[0]` knowing the resource exists, or return `null` when it doesn't.


## Clean Up

```bash
# Destroy dev resources
terraform workspace select dev
terraform destroy -var-file="dev.tfvars"

# Destroy staging resources
terraform workspace select staging
terraform destroy -var-file="staging.tfvars"

# Switch to default workspace
terraform workspace select default
```

Type `yes` when prompted for destroy.

---

## Documentation Links

- [count Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count)
- [Conditional Expressions](https://developer.hashicorp.com/terraform/language/expressions/conditionals)
- [Terraform Workspaces](https://developer.hashicorp.com/terraform/cli/workspaces)
