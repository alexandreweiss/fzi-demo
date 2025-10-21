variable "customer_name" {
  description = "Name of customer to be used in resources"
  default     = "contoso"
}

variable "application_1" {
  description = "Name of application 1"
  default     = "MyApp1"
}

variable "application_2" {
  description = "Name of application 2"
  default     = "MyApp2"
}

variable "application_3" {
  description = "Name of application 3"
  default     = "MyApp3"
}

variable "customer_website" {
  description = "FQDN of customer website"
  default     = "www.aviatrix.com"
}


variable "azure_r1_location" {
  default     = "West Europe"
  description = "region to deploy resources"
  type        = string
}

variable "azure_r1_location_short" {
  default     = "we"
  description = "region to deploy resources"
  type        = string
}

variable "aws_r1_location" {
  default     = "eu-central-1"
  description = "region to deploy resources"
  type        = string
}

variable "aws_r1_location_short" {
  default     = "fra"
  description = "region to deploy resources"
  type        = string
}

variable "aws_r2_location" {
  default     = "eu-west-3"
  description = "region to deploy resources"
  type        = string
}

variable "aws_r2_location_short" {
  default     = "par"
  description = "region to deploy resources"
  type        = string
}

variable "admin_password" {
  sensitive   = true
  description = "Admin password"
}

variable "controller_fqdn" {
  description = "FQDN or IP of the Aviatrix Controller"
  sensitive   = true
}

variable "ssh_public_key" {
  sensitive   = true
  description = "SSH public key for VM administration"
}

variable "aws_account" {
  description = "CSP account onboarder on the controller"
}

variable "use_profile" {
  type        = bool
  description = "Use profile for AWS provider"
  default     = true
}

variable "pod_arn" {
  type        = string
  description = "AWS arn role for the admin permissions for the pod."
  # default     = "arn:aws:iam::211098808963:user/admin-key"
  default = "dummy"
}

variable "human_admin_arn" {
  description = "ARN of the human admin user"
}

variable "deploy_vpn_gateway" {
  type        = bool
  default     = false
  description = "Whether to deploy the VPN gateway in control plane VPC"
}

variable "human_admin_cidr" {
  description = "CIDR block for the human admin user"
  default     = "10.0.0.0/8"
}
