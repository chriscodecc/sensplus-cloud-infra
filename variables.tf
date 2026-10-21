

variable "location" {
  type    = string
  default = "westeurope"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_username" {
  type      = string
  sensitive = true
}
