provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "demo" {
  #ami           = "ami-0532be01f26a3de55" # Amazon Linux 2 (example)
  ami = "ami-024ee5112d03921e2"
  instance_type = "t2.micro"

  tags = var.common_tags
  lifecycle {
    create_before_destroy = true
    prevent_destroy = false
  }
}
