# Dev environment: minimal servers
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
