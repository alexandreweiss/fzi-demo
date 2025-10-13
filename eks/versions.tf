# terraform {
#   required_providers {
#     aviatrix = {
#       source  = "aviatrixsystems/aviatrix"
#       version = "~> 3.1.5"
#     }
#     aws = {
#       source = "hashicorp/aws"
#     }
#     kubernetes = {
#       source = "hashicorp/kubernetes"
#     }
#   }
#   required_version = ">= 0.13"
# }
# # Or optionally pass the credentials using other means, such as ENV VAR
# provider "aviatrix" {
#   controller_ip           = var.aviatrix_controller_ip
#   username                = var.aviatrix_controller_username
#   password                = var.aviatrix_controller_password
#   skip_version_validation = true
# }

# provider "aws" {
#   region     = var.aws_region
#   access_key = var.aws_access_key
#   secret_key = var.aws_secret_key
# }

# provider "aws" {
#   alias      = "east"
#   region     = "us-east-2"
#   access_key = var.aws_access_key
#   secret_key = var.aws_secret_key
# }
# provider "aws" {
#   alias      = "west"
#   region     = "us-west-1"
#   access_key = var.aws_access_key
#   secret_key = var.aws_secret_key
# }
