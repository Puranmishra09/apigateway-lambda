variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "domain_name" { default = "example.com" }
variable "api_subdomain" { default = "api.example.com" }
