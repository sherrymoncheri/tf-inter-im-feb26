# Lab 4: Lifecycle Configuration

## Controlling Resource Updates and Preventing Accidental Deletions

---

## Objective

Learn to control how Terraform manages resource lifecycles using the `lifecycle` block to implement zero-downtime updates, protect critical resources from deletion, and handle externally modified attributes.

---

## Time Estimate

**30-35 minutes**

---

## What You'll Learn

- Using `create_before_destroy` for zero-downtime updates
- Using `prevent_destroy` to protect critical resources
- Using `ignore_changes` to handle external modifications
- Understanding when to use each lifecycle option
- Best practices for lifecycle management in production

---

## High-Level Instructions

1. Create project structure with EC2, security group, and S3 bucket
2. Implement `create_before_destroy` on security group and EC2
3. Add `prevent_destroy` to critical S3 bucket
4. Use `ignore_changes` to handle external tag modifications
5. Test lifecycle behaviors
6. Clean up resources (requires removing prevent_destroy first)

---

## Detailed Instructions

### Step 1: Create Your Working Directory

```bash
cd ~
mkdir lab4-im
cd lab4-im
```

---

### Step 2: Create Terraform Configuration

**Create `terraform.tf`:**

```bash
cp ~/intermediate/day1/labs/lab4/lab4-solution/terraform.tf .
```

```hcl
terraform {
  required_version = "~> 1.13.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.20.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      owner  = var.project
      Course = "Terraform-Intermediate"
      Lab    = "lab4"
    }
  }
}
```

---

### Step 3: Create Variables File

**Create `variables.tf`:**

```bash
cp ~/intermediate/day1/labs/lab4/lab4-solution/variables.tf .
```

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "project" {
  description = "Use userX format, replace X with your user number. Uncomment default to avoid prompt."
  type        = string
  # default   = "userX"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "ingress_rules" {
  description = "List of ingress rules for security group"
  type = list(object({
    port        = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP"
    },
    {
      port        = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS"
    }
  ]
}
```

> **Action Required:** Edit `variables.tf` and uncomment the default value for `project` by removing the `#` at the beginning of the line, then replace `X` with your user number (e.g., `default = "user1"`).

---

### Step 4: Create Locals File

**Create `locals.tf`:**

```bash
cp ~/intermediate/day1/labs/lab4/lab4-solution/locals.tf .
```

```hcl
locals {
  # Common prefix for all resources
  name_prefix = "${var.project}-${var.environment}"

  # Server name
  server_name = "lab4-${local.name_prefix}-web"

  # Transform ingress_rules list into map for for_each
  ingress_rule_map = {
    for rule in var.ingress_rules :
    format("%s-%d", rule.protocol, rule.port) => rule
  }
}
```

---

### Step 5: Create Main Configuration with Lifecycle Blocks

This is the key file demonstrating all lifecycle options.

**Create `main.tf`:**

```bash
cp ~/intermediate/day1/labs/lab4/lab4-solution/main.tf .
```

```hcl
# Random suffix for unique names
resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

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
  subnet_id              = data.aws_subnets.default.ids[0]
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
```

---

### Step 6: Create Outputs File

**Create `outputs.tf`:**

```bash
cp ~/intermediate/day1/labs/lab4/lab4-solution/outputs.tf .
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
```

---

### Step 7: Create Variable Files

**Create `dev.tfvars`:**

```bash
cp ~/intermediate/day1/labs/lab4/lab4-solution/dev.tfvars .
```

```hcl
environment = "dev"

# Ingress rules (no SSH per format requirements)
ingress_rules = [
  {
    port        = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  },
  {
    port        = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }
]
```

---

### Step 8: Initialize and Deploy

```bash
# Initialize
terraform init

# Validate
terraform validate

# Plan
terraform plan -var-file="dev.tfvars"

# Apply
terraform apply -var-file="dev.tfvars"
```

---

### Step 9: Test prevent_destroy

Try to destroy everything - you'll see the prevent_destroy protection in action:

```bash
terraform destroy -var-file="dev.tfvars"
```

**Expected error:**
```
╷
│ Error: Instance cannot be destroyed
│ 
│   on main.tf line 109:
│  109: resource "aws_s3_bucket" "data" {
│ 
│ Resource aws_s3_bucket.data has lifecycle.prevent_destroy set, but the plan calls for
│ this resource to be destroyed. To avoid this error and continue with the plan, either
│ disable lifecycle.prevent_destroy or reduce the scope of the plan using the -target
│ option.
```

This demonstrates that the `prevent_destroy` lifecycle setting is protecting the critical S3 bucket!

---

### Step 10: Test ignore_changes

Add a tag to the instance externally (simulating an external process):

```bash
# Get instance ID
INSTANCE_ID=$(terraform output -raw instance_id)

# Add a tag via AWS CLI (simulating external modification)
aws ec2 create-tags \
  --resources $INSTANCE_ID \
  --tags Key=LastModifiedBy,Value=external-process \
  --region us-west-1

# Run plan - notice Terraform does NOT try to remove the tag
terraform plan -var-file="dev.tfvars"
```

The plan should show "No changes" because the `LastModifiedBy` tag is in the `ignore_changes` list.

---

### Step 11: Test create_before_destroy

Add a new ingress rule to see security group behavior:

```bash
# Edit dev.tfvars and add this rule to ingress_rules, 
# between  closing curly bracket } and closing square bracker ] 
  ,
  {
     port        = 8080
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
     description = "Custom app port"
   }


# Then plan to see the behavior
terraform plan -var-file="dev.tfvars"
```

Notice that for security group rule changes with `create_before_destroy`:
1. New rules are created first
2. Old rules are destroyed after (if needed)

---

## Verification Checklist

```bash
# Verify resources were created
terraform output instance_id
terraform output data_bucket_name

# Verify lifecycle info
terraform output lifecycle_info
```

---

## Clean Up

To destroy resources with `prevent_destroy`, you must first remove that setting:

1. **Edit `main.tf`** and comment out `prevent_destroy = true` in the `aws_s3_bucket.data` resource:

```hcl
resource "aws_s3_bucket" "data" {
  # ... other config ...

  lifecycle {
    # prevent_destroy = true  # COMMENT OUT THIS LINE
  }
}
```

2. **Apply the change** (this updates the lifecycle setting):

```bash
terraform apply -var-file="dev.tfvars"
```

3. **Now destroy will work:**

```bash
terraform destroy -var-file="dev.tfvars"
```

---

## Key Concepts Recap

### Lifecycle Block Options

```hcl
# Key concept: Lifecycle block options
lifecycle {
  # Create replacement before destroying original (zero-downtime)
  create_before_destroy = true

  # Prevent terraform destroy from removing this resource
  prevent_destroy = true

  # Ignore changes to specific attributes
  ignore_changes = [
    tags["ExternalTag"],
    tags["LastModifiedBy"],
  ]
}
```

### When to Use Each Option

- **`create_before_destroy`**: Zero-downtime updates, resources attached to other resources
- **`prevent_destroy`**: Critical data stores, production databases, important S3 buckets
- **`ignore_changes`**: Externally managed attributes, tags set by AWS, drift you want to allow

### Best Practices

1. **Security Groups**: Always use `create_before_destroy` when attached to running instances
2. **Critical Data**: Use `prevent_destroy` for production databases and important S3 buckets
3. **External Modifications**: Use `ignore_changes` for tags that AWS or other tools might modify
4. **Documentation**: Comment why each lifecycle option is used

---

## Documentation Links

- [Lifecycle Meta-Arguments](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [create_before_destroy](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#create_before_destroy)
- [prevent_destroy](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#prevent_destroy)
- [ignore_changes](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#ignore_changes)
