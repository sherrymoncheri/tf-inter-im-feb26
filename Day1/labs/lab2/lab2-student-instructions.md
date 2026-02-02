# Lab 2: Dynamic EC2 Deployment with for_each

## Building Flexible Infrastructure from Configuration Maps

---

## Objective

Deploy multiple EC2 instances dynamically using `for_each` with maps of objects. Learn how to create flexible, data-driven infrastructure where adding or removing servers is as simple as editing a configuration map.

---

## Time Estimate

**40-45 minutes**

---

## What You'll Learn

- Using `for_each` with maps of objects (complex data structures)
- Creating dynamic security groups based on server tiers
- How `for_each` handles additions and removals gracefully
- Environment-specific configurations via tfvars files

---

## High-Level Instructions

1. Create project structure with server configuration map
2. Implement `for_each`-based EC2 instance creation
3. Create dynamic security groups based on server tiers
4. Add IAM role and instance profile
5. Deploy to dev environment
6. Modify the server map and observe Terraform's behavior
7. Clean up resources

---

## Detailed Instructions

### Step 1: Create Your Working Directory

```bash
cd ~
mkdir -p lab2-im
cd lab2-im
```

---

### Step 2: Create Terraform Configuration

**Copy `terraform.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/terraform.tf .
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
      Lab    = "lab2"
    }
  }
}
```

---

### Step 3: Create Variables File

**Copy `variables.tf` from the solution directory:**

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/variables.tf .
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

# This is the key variable - a map of objects defining our servers
variable "servers" {
  description = "Map of server configurations"
  type = map(object({
    instance_type = string
    tier          = string
  }))
}
```

> **Action Required:** Edit `variables.tf` to uncomment the `default` line for the `project` variable and replace `X` with your assigned user number. To uncomment, remove the `#` at the beginning of the line (e.g., change `# default = "userX"` to `default = "user3"` if you are user 3).

**Understanding the `servers` variable:**

This is a **map of objects** - each key is a server name, and the value is an object containing:
- `instance_type`: The EC2 instance size
- `tier`: The server's tier (web, db) - used for security group assignment

---

### Step 4: Create Locals File

**Copy `locals.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/locals.tf .
```

```hcl
locals {
  environment = terraform.workspace

  # Name prefix for all resources
  name_prefix = "lab2-${var.project}-${local.environment}"

  # Key concept: extracting unique values using for expression and toset()
  server_tiers = toset([for server in var.servers : server.tier])
}
```

**What's happening here:**
- `name_prefix`: Creates a consistent naming prefix for all resources
- `server_tiers`: Extracts unique tiers using a for expression, then converts to a set

---

### Step 5: Create Main Configuration

**Copy `main.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/main.tf .
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
```

**Key concepts in this file:**

1. **`local.name_prefix`**: Consistent naming across all resources with lab2 prefix
2. **`for_each = local.server_tiers`**: Creates one security group per unique tier
3. **`for_each = var.servers`**: Creates one EC2 instance per server in the map
4. **`each.key`**: The map key (server name like "web-1")
5. **`each.value`**: The object containing instance_type and tier
6. **Standalone egress rule**: Best practice using `aws_vpc_security_group_egress_rule` instead of inline block
7. **Conditional ingress rules**: The pattern `count = contains(local.server_tiers, "web") ? 1 : 0` checks if "web" exists in the tiers set. If true, creates 1 resource; if false, creates 0. This lets us create tier-specific rules only when that tier is present.

---

### Step 6: Create Outputs File

**Copy `outputs.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/outputs.tf .
```

```hcl
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
```

---

### Step 7: Create Environment-Specific Variable Files

**Copy `dev.tfvars` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/dev.tfvars .
```

```hcl
# Dev environment: minimal servers
servers = {
  "web-1" = {
    instance_type = "t3.nano"
    tier          = "web"
  }
  "db-1" = {
    instance_type = "t3.nano"
    tier          = "db"
  }
}
```

**Copy `staging.tfvars` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/staging.tfvars .
```

```hcl
# Staging: more web servers, larger database
servers = {
  "web-1" = {
    instance_type = "t3.nano"
    tier          = "web"
  }
  "web-2" = {
    instance_type = "t3.nano"
    tier          = "web"
  }
  "db-1" = {
    instance_type = "t3.micro"
    tier          = "db"
  }
}
```

---

### Step 8: Initialize the Dev Environment

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Create dev workspace
terraform workspace new dev

# Plan with dev environment
terraform plan -var-file="dev.tfvars"
```

**Review the plan output.** You should see:
- 2 EC2 instances (web-1, db-1)
- 2 security groups (web, db)
- 1 IAM role and instance profile
- Security group rules for HTTP and MySQL

```bash
# Apply the configuration
terraform apply -var-file="dev.tfvars"
```

Type `yes` when prompted.

---

### Step 9: Verify the Deployment

```bash
# View all outputs
terraform output

# View specific output
terraform output server_details
```

---

### Step 10: Demonstrate for_each Behavior - Add a Server

Copy `dev-add-server.tfvars` from solution directory to `dev.tfvars` in lab directory to add a second web server:

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/dev-add-server.tfvars dev.tfvars
```

Current content of dev.tfvars:
```hcl
servers = {
  "web-1" = {
    instance_type = "t3.nano"
    tier          = "web"
  }
  # ADD THIS NEW SERVER
  "web-2" = {
    instance_type = "t3.nano"
    tier          = "web"
  }
  "db-1" = {
    instance_type = "t3.nano"
    tier          = "db"
  }
}
```

Run plan to see what changes:

```bash
terraform plan -var-file="dev.tfvars"
```

**Notice:**
- Terraform will ADD 1 instance (`aws_instance.servers["web-2"]`)
- **Existing instances are NOT touched!**
- The web security group is reused (already exists)

This is the key advantage of `for_each` over `count` - resources are tracked by their map key, not by index.

```bash
# Apply the change
terraform apply -var-file="dev.tfvars"
```

---

### Step 11: Demonstrate for_each Behavior - Remove a Server

Now, copy `dev-remove-server.tfvars` from solution directory to `dev.tfvars` in lab directory to remove a second web server:

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/dev-remove-server.tfvars dev.tfvars
```

Current content of dev.tfvars:
```hcl
servers = {
  "web-1" = {
    instance_type = "t3.nano"
    tier          = "web"
  }
  # web-2 REMOVED
  "db-1" = {
    instance_type = "t3.nano"
    tier          = "db"
  }
}
```

Run plan:

```bash
terraform plan -var-file="dev.tfvars"
```

**Notice:**
- Terraform will DESTROY only `aws_instance.servers["web-2"]`
- web-1 and db-1 remain unchanged
- The web security group remains (still has web-1)

**Don't apply this change** - we want to keep the servers for cleanup demonstration.

Restore web-2 in `dev.tfvars` before continuing:

```bash
cp ~/intermediate/day1/labs/lab2/lab2-solution/dev-add-server.tfvars dev.tfvars
```

---

### Step 12: Test Staging Environment

Now let's see how staging differs:

```bash
# Create staging workspace
terraform workspace new staging

# Plan with staging
terraform plan -var-file="staging.tfvars"

# Apply with staging environment
terraform apply -var-file="staging.tfvars"
```

Notice how staging creates 3 servers (2 web, 1 db) with a larger instance type for the database.

---

## Key Concepts Recap

### for_each with Maps of Objects

```hcl
variable "servers" {
  type = map(object({
    instance_type = string
    tier          = string
  }))
}

resource "aws_instance" "servers" {
  for_each      = var.servers
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = each.value.instance_type  # Access object properties
  tags = {
    Name = each.key  # The map key becomes the identifier
  }
}
```

### Extracting Unique Values

```hcl
# Get unique tiers from a map
local.server_tiers = toset([for server in var.servers : server.tier])
# Result: ["web", "db"]
```

---

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

- [for_each Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [Complex Variable Types](https://developer.hashicorp.com/terraform/language/expressions/type-constraints#structural-types)
- [For Expressions](https://developer.hashicorp.com/terraform/language/expressions/for)
- [AWS Instance Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance)
