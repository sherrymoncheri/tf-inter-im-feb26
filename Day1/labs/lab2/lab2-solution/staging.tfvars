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
