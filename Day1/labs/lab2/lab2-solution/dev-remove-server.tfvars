# Dev environment: minimal servers
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
