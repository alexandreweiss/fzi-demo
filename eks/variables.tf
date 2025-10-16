# variable "aws_region" {}
# variable "aws_access_key" {}
# variable "aws_secret_key" {}

# variable "aviatrix_controller_ip" {}
# variable "aviatrix_controller_username" {}
# variable "aviatrix_controller_password" {}
# variable "aviatrix_aws_access_account" {}

# variable "ssh_user" {
#   default = "ubuntu"
# }

variable "cluster_name" {}
variable "vpc_id" {}
variable "private_subnet_ids" {}
variable "aviatrix_aws_account_arn" {}                       # data.aviatrix_account.aws_account.aws_role_arn
variable "control_plane_subnet_cidr" { type = list(string) } # Control plane subnet where controller is to open ingress to cluster
