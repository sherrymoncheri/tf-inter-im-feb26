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
