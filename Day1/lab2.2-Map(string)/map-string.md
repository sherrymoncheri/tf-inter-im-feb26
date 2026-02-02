
# 🧪 Terraform Lab: Understanding and Using `map(string)`

## 🎯 Lab Objective

By the end of this lab, you will:

* Understand what `map(string)` means in Terraform
* Declare and use a `map(string)` variable
* Access values from a map
* Merge maps dynamically
* Override map values using `terraform.tfvars`
* Use maps in real AWS resources (tags)

---

## 🏗️ Lab Architecture

We will create:

* 1 EC2 instance
* Tags will be dynamically applied using a **map(string)** variable

![Image](https://docs.aws.amazon.com/images/AWSEC2/latest/UserGuide/images/get-started-diagram.png)

![Image](https://media.amazonwebservices.com/blog/2017/ec2_tag_on_create_1.png)

![Image](https://miro.medium.com/v2/resize%3Afit%3A1400/1%2A7x7SmXVPuUZyP9GbOISZbA.png)

---

## 📁 Step 1: Create Project Structure

```bash
mkdir terraform-map-lab
cd terraform-map-lab
touch main.tf variables.tf terraform.tfvars outputs.tf
```

---

## 🧩 Step 2: Define a `map(string)` Variable

📄 **variables.tf**

```hcl
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)

  default = {
    Environment = "dev"
    Owner       = "DevOps-Team"
    Project     = "Terraform-Lab"
  }
}
```

👉 Here:

* Keys = `Environment`, `Owner`
* Values = **strings only**

---

## 🖥️ Step 3: Create EC2 Instance Using Map

📄 **main.tf**

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "demo" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 (example)
  instance_type = "t2.micro"

  tags = var.common_tags
}
```

✔ Terraform will automatically apply **all key-value pairs as EC2 tags**

---

## 🔍 Step 4: Access a Specific Map Value

📄 **outputs.tf**

```hcl
output "environment_tag" {
  value = var.common_tags["Environment"]
}
```

Run:

```bash
terraform apply
```

You will see:

```
environment_tag = "dev"
```

---

## ➕ Step 5: Add More Tags Using `merge()`

We now add a **Name tag dynamically**

📄 Update **main.tf**

```hcl
resource "aws_instance" "demo" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  tags = merge(
    var.common_tags,
    {
      Name = "map-string-demo-instance"
    }
  )
}
```

👉 `merge()` combines two maps into one.

---

## 🧪 Step 6: Override Map Values via tfvars

📄 **terraform.tfvars**

```hcl
common_tags = {
  Environment = "uat"
  Owner       = "Cloud-Team"
  CostCenter  = "CC-101"
}
```

Now run:

```bash
terraform apply
```

Terraform will replace the default tags with these new ones.

---

## 🧠 Step 7: Convert Map Value to Number (Important Concept)

Because **map(string)** only stores strings:

```hcl
variable "server_settings" {
  type = map(string)
  default = {
    volume_size = "30"
  }
}
```

Use it like this:

```hcl
volume_size = tonumber(var.server_settings["volume_size"])
```

---

## 🧹 Step 8: Destroy Resources

```bash
terraform destroy
```

---

## 📌 Key Takeaways

| Concept         | What You Learned                                    |
| --------------- | --------------------------------------------------- |
| `map(string)`   | Stores key-value pairs where values must be strings |
| Access map      | `var.map_name["key"]`                               |
| Merge maps      | `merge(map1, map2)`                                 |
| Override values | Using `terraform.tfvars`                            |
| Type conversion | Use `tonumber()` if number stored as string         |

---

## 🏁 Lab Completed

You now know how to use **map(string)** for:

✔ Tags
✔ Metadata
✔ Simple configuration inputs

