provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "demo" {
  count = 1
  ami           = "ami-0532be01f26a3de55" # Amazon Linux 3 (example)
  instance_type = "t2.micro"
  key_name = "key1-vishwa"

  tags = {
    Name = local.name
  }
}

locals {
  name =  format("%s-wed-%s-%02d", var.project, var.env,18)  
}

resource "null_resource" "local_exe" {

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p outputs
      cat > outputs/demo_private_ips.txt <<'EOF'
${join("\n", aws_instance.demo[*].private_ip)}
EOF
    EOT
  }
}


resource "null_resource" "cp-file" {
  
  connection {
    type = "ssh"
    user = "ec2-user"
    host = aws_instance.demo[0].public_ip
    private_key = file("key1-vishwa.pem")
  }

  provisioner "file" {
    source = "sample_file.txt"
    destination = "/home/ec2-user/sample_file.txt"
  }

}

