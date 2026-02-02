# Lab 3: Advanced Terraform Functions

## Mastering String, List, and Map Manipulation

---

## Objective

Learn to use advanced Terraform functions (`templatefile`, `format`, `flatten`, `zipmap`, `merge`) to build reusable input structures and handle multi-environment data with maps.

---

## Time Estimate

**30-35 minutes**

---

## What You'll Learn

- Using `templatefile()` to render dynamic configuration files
- Using `format()` for string formatting with placeholders
- Using `flatten()` to convert nested lists into flat lists
- Using `zipmap()` to create maps from two parallel lists
- Using `merge()` to combine multiple maps into one
- Building reusable input structures with `variables.tf` and `locals.tf`

---

## High-Level Instructions

1. Create project structure with template file
2. Define complex variable structures for function demonstrations
3. Use `locals.tf` to demonstrate all five functions
4. Create EC2 instance using the processed data
5. Verify function results through outputs
6. Clean up resources

---

## Detailed Instructions

### Step 1: Create Your Working Directory

```bash
cd ~
mkdir -p lab3-im/templates
cd lab3-im
```

---

### Step 2: Create User Data Template

This template file demonstrates the `templatefile()` function with variable interpolation, loops, and conditionals.

**Copy `templates/user_data.tftpl` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab3/lab3-solution/templates/user_data.tftpl templates/
```

```bash
#!/bin/bash
set -e

# Variables passed from Terraform
ENVIRONMENT="${environment}"
SERVER_NAME="${server_name}"
PROJECT="${project}"

# Install packages
yum install -y httpd

# Create index page with server info
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>$SERVER_NAME</title>
</head>
<body>
    <h1>Welcome to $SERVER_NAME</h1>
    <div class="info">
        <p><strong>Environment:</strong> $ENVIRONMENT</p>
        <p><strong>Project:</strong> $PROJECT</p>
        <p><strong>Instance:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
        <p><strong>AZ:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
    </div>
</body>
</html>
EOF

# Configure services using template for loop
%{ for service in services ~}
echo "Enabling service: ${service}"
systemctl enable ${service} || true
systemctl start ${service} || true
%{ endfor ~}

echo "Server $SERVER_NAME initialization complete"
```

**Template features demonstrated:**
- `${variable}` - Simple variable interpolation
- `%{ for ... }` - Template directive for loops

---

### Step 3: Create Terraform Configuration

**Copy `terraform.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab3/lab3-solution/terraform.tf .
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
      Lab    = "lab3"
    }
  }
}
```

---

### Step 4: Create Variables File

**Copy `variables.tf` from the solution directory:**

```bash
cp ~/intermediate/day1/labs/lab3/lab3-solution/variables.tf .
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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "services" {
  description = "List of services to enable on the instance"
  type        = list(string)
  default     = ["httpd"]
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Team      = "Platform"
  }
}

variable "environment_tags" {
  description = "Environment-specific tags"
  type        = map(string)
  default     = {}
}

variable "security_group_rules" {
  description = "Nested security group rules - will be flattened for resource creation"
  type = list(object({
    name        = string
    protocol    = string
    cidr_blocks = list(string)
    ports       = list(number)
  }))
  default = [
    {
      name        = "web"
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      ports       = [80, 443]
    }
  ]
}

variable "tiers" {
  description = "List of tiers"
  type        = list(string)
  default     = ["web", "db"]
}

variable "server_types" {
  description = "List of instance types corresponding to tiers"
  type        = list(string)
  default     = ["t3.nano", "t3.micro"]
}
```

> **Action Required:** Edit `variables.tf` to uncomment the `default` line for the `project` variable and replace `X` with your assigned user number. To uncomment, remove the `#` at the beginning of the line (e.g., change `# default = "userX"` to `default = "user3"` if you are user 3).

---

### Step 5: Create Locals File

This is the key file that demonstrates all five functions.

**Copy `locals.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab3/lab3-solution/locals.tf .
```

```hcl
locals {
  name_prefix = "lab3-${var.project}-${var.environment}"

  # Key concept: simple string joining - use interpolation
  server_name = "${local.name_prefix}-web"

  # Key concept: format() for complex formatting (zero-padding)
  # format("%s-web-%02d", "lab3-user1-dev", 1) -> "lab3-user1-dev-web-01"
  formatted_server_name = format("%s-web-%02d", local.name_prefix, 1)

  # Key concept: templatefile() renders template with variables
  user_data = templatefile("${path.module}/templates/user_data.tftpl", {
    environment = var.environment
    server_name = local.server_name
    project     = var.project
    services    = var.services
  })

  # Key pattern: flatten() converts nested rule groups into flat list for for_each
  # Input: [{name="web", ports=[80,443]}, {name="db", ports=[3306]}]
  # Output: [{name="web", port=80}, {name="web", port=443}, {name="db", port=3306}]
  flattened_rules = flatten([
    for rule in var.security_group_rules : [
      for port in rule.ports : {
        key         = "${rule.name}-${port}"
        name        = rule.name
        port        = port
        protocol    = rule.protocol
        cidr_blocks = rule.cidr_blocks
      }
    ]
  ])

  # Key pattern: convert flattened list to map for for_each
  ingress_rule_map = {
    for rule in local.flattened_rules : rule.key => rule
  }

  # Key concept: zipmap() creates map from two parallel lists
  # zipmap(["web", "db"], ["t3.nano", "t3.micro"]) -> {web = "t3.nano", db = "t3.micro"}
  tier_instance_types = zipmap(var.tiers, var.server_types)

  # Key concept: merge() combines maps (later values override earlier)
  all_tags = merge(
    var.common_tags,
    var.environment_tags,
    {
      Name        = local.server_name
      Environment = var.environment
    }
  )
}
```

**Key functions explained:**

- `format()` - String formatting with special placeholders like `%02d`
  - Use interpolation `"${var}-suffix"` for simple joining
  - Use `format()` for padding: `format("%s-%02d", "web", 1)` → `"web-01"`
- `templatefile()` - Render template with variables
  - Example: `templatefile("template.tftpl", {name = "value"})`
- `flatten()` - Convert nested lists to flat list
  - Example: `flatten([[1,2], [3,4]])` → `[1, 2, 3, 4]`
- `zipmap()` - Create map from two lists
  - Example: `zipmap(["a","b"], [1,2])` → `{a=1, b=2}`
- `merge()` - Combine multiple maps
  - Example: `merge({a=1}, {b=2})` → `{a=1, b=2}`

---

### Step 6: Create Main Configuration

**Copy `main.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab3/lab3-solution/main.tf .
```

```hcl
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

resource "aws_security_group" "web_sg" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web server"

  tags = local.all_tags
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-egress-all"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rules" {
  for_each = local.ingress_rule_map

  security_group_id = aws_security_group.web_sg.id
  description       = each.value.name
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_blocks[0]

  tags = {
    Name = "${local.name_prefix}-${each.key}"
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(local.all_tags, {
    Name = "${local.name_prefix}-ec2-role"
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = local.tier_instance_types["web"]
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = local.user_data

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.all_tags, {
    Name = local.server_name
  })
}
```

---

### Step 7: Create Outputs File

**Copy `outputs.tf` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab3/lab3-solution/outputs.tf .
```

```hcl
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
```

---

### Step 8: Create Variable Files

**Copy `dev.tfvars` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab3/lab3-solution/dev.tfvars .
```

```hcl
environment = "dev"

services = ["httpd"]

# Tags for merge() demonstration
common_tags = {
  ManagedBy = "Terraform"
  Team      = "Platform"
}

environment_tags = {
  CostCenter = "development"
}

# Security group rules - nested structure that gets flattened
security_group_rules = [
  {
    name        = "web"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ports       = [80, 443]
  }
]

# For zipmap()
tiers        = ["web", "db"]
server_types = ["t3.nano", "t3.micro"]
```

**Copy `staging.tfvars` from the solution directory, or create it with the following content:**

```bash
cp ~/intermediate/day1/labs/lab3/lab3-solution/staging.tfvars .
```

```hcl
environment = "staging"

services = ["httpd"]

# Tags for merge() demonstration - staging has more tags
common_tags = {
  ManagedBy = "Terraform"
  Team      = "Platform"
}

environment_tags = {
  CostCenter  = "staging"
  Compliance  = "required"
  BackupLevel = "daily"
}

# Security group rules - staging has more rule groups to flatten
security_group_rules = [
  {
    name        = "web"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ports       = [80, 443]
  },
  {
    name        = "db"
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    ports       = [3306, 5432]
  }
]

# For zipmap()
tiers        = ["web", "db"]
server_types = ["t3.nano", "t3.micro"]
```

---

### Step 9: Initialize and Deploy

```bash
# Initialize
terraform init

# Validate
terraform validate

# Plan with dev environment
terraform plan -var-file="dev.tfvars"

# Apply
terraform apply -var-file="dev.tfvars"
```

---

### Step 10: Explore Function Results

After deployment, examine the outputs to see how each function works:

```bash
# View all outputs
terraform output

# Examine specific function results
terraform output server_name              # interpolation result
terraform output formatted_server_name    # format() with %02d
terraform output flattened_rules          # flatten() result
terraform output ingress_rule_map         # flatten + for_each map
terraform output tier_instance_types      # zipmap() result
terraform output all_tags                 # merge() result
terraform output user_data_preview        # templatefile() result
```

---

### Step 11: Compare Environments

Try deploying with staging to see how the same functions produce different results:

```bash
# Destroy dev first
terraform destroy -var-file="dev.tfvars"

# Deploy staging
terraform apply -var-file="staging.tfvars"

# Compare outputs - notice more rules and more tags in staging
terraform output flattened_rules      # dev: 2 rules, staging: 4 rules
terraform output tier_instance_types
terraform output all_tags
```

---

## Verification Checklist

```bash
# Verify instance was created
terraform output instance_id
terraform output instance_public_ip

# Verify interpolation and format()
terraform output server_name
# Expected: lab3-userX-dev-web (interpolation)
terraform output formatted_server_name
# Expected: lab3-userX-dev-web-01 (format with %02d)

# Verify flatten() function
terraform output flattened_rules
# Expected: 2 rules for dev (web-80, web-443), 4 rules for staging

# Verify zipmap() function
terraform output tier_instance_types
# Expected: {web = "t3.nano", db = "t3.micro"}

# Verify merge() function
terraform output all_tags
# Expected: Combined map with ManagedBy, Team, CostCenter, Name, Environment

# Verify templatefile() function
terraform output user_data_preview
```

---

## Clean Up

```bash
terraform destroy -var-file="dev.tfvars"
```

---

## Key Concepts Recap

### format() Function
```hcl
# Key concept: format() for special string formatting
# For simple string joining, use interpolation:
server_name = "${var.project}-${var.environment}-web"  # "myproject-dev-web"

# Use format() when you need special formatting like zero-padding:
format("server-%02d", 1)   # "server-01"
format("server-%02d", 12)  # "server-12"
```

### templatefile() Function
```hcl
# Key concept: templatefile() renders template with variables
templatefile("${path.module}/templates/config.tftpl", {
  server_name = "web-server"
  ports       = [80, 443]
})
```

### flatten() Function
```hcl
# Key pattern: flatten() converts nested lists to flat list
flatten([[1, 2], [3, 4]])  # [1, 2, 3, 4]

# Key pattern: flatten nested for expressions for for_each
flatten([
  for group in var.groups : [
    for item in group.items : {
      group = group.name
      item  = item
    }
  ]
])
```

### zipmap() Function
```hcl
# Key concept: zipmap() creates map from two parallel lists
zipmap(["a", "b", "c"], [1, 2, 3])  # {a = 1, b = 2, c = 3}
```

### merge() Function
```hcl
# Key concept: merge() combines maps (later values override earlier)
merge(
  {a = 1, b = 2},
  {b = 3, c = 4}
)  # {a = 1, b = 3, c = 4}
```

---

## Documentation Links

- [templatefile Function](https://developer.hashicorp.com/terraform/language/functions/templatefile)
- [format Function](https://developer.hashicorp.com/terraform/language/functions/format)
- [flatten Function](https://developer.hashicorp.com/terraform/language/functions/flatten)
- [zipmap Function](https://developer.hashicorp.com/terraform/language/functions/zipmap)
- [merge Function](https://developer.hashicorp.com/terraform/language/functions/merge)
