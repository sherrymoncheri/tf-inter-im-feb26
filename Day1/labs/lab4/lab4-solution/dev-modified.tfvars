environment = "dev"

# Ingress rules
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
  },
   {
     port        = 8080
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
     description = "Custom app port"
   }
]
