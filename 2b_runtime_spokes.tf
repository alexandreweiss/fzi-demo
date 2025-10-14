# Spokes from non_pci domain across two AWS regions
module "spoke_aws_r1_np_0" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "8.0.0"

  cloud          = "AWS"
  name           = "RuntimeA"
  cidr           = "10.2.0.0/21"
  region         = var.aws_r1_location
  account        = var.aws_account
  transit_gw     = module.backbone.transit.transit1a.transit_gateway.gw_name
  network_domain = module.network_domains.network_domains[1]
  ha_gw          = false
  attached       = true
  single_ip_snat = true
  subnet_size    = "24"
  subnet_pairs   = "2"
}


# module "spoke_aws_r1_np_1" {
#   source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
#   version = "8.0.0"

#   cloud          = "AWS"
#   name           = "RuntimeB"
#   cidr           = "10.2.1.0/24"
#   region         = var.aws_r1_location
#   account        = var.aws_account
#   transit_gw     = module.backbone.transit.transit1a.transit_gateway.gw_name
#   network_domain = module.network_domains.network_domains[1]
#   ha_gw          = false
# }

# module "spoke_aws_r1_shared_0" {
#   source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
#   version = "8.0.0"

#   cloud          = "AWS"
#   name           = "Shared"
#   cidr           = "10.2.3.0/24"
#   region         = var.aws_r1_location
#   account        = var.aws_account
#   transit_gw     = module.backbone.transit.transit1a.transit_gateway.gw_name
#   network_domain = module.network_domains.network_domains[2]
#   ha_gw          = false
# }

# module "spoke_aws_r2_np_2" {
#   source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
#   version = "8.0.0"

#   cloud          = "AWS"
#   name           = "RuntimeC"
#   cidr           = "10.3.0.0/24"
#   region         = var.aws_r2_location
#   account        = var.aws_account
#   transit_gw     = module.backbone.transit.transit1b.transit_gateway.gw_name
#   network_domain = module.network_domains.network_domains[1]
#   ha_gw          = false
# }

# # Spoke from pci domain in AWS region 1

# module "spoke_aws_r1_p_0" {
#   source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
#   version = "8.0.0"

#   cloud          = "AWS"
#   name           = "runtimeD"
#   cidr           = "10.2.2.0/24"
#   region         = var.aws_r1_location
#   account        = var.aws_account
#   transit_gw     = module.backbone.transit.transit1a.transit_gateway.gw_name
#   network_domain = module.network_domains.network_domains[3]
#   ha_gw          = false
# }

# output "private_subnets" {
#   value = {
#     spoke_aws_r1_np_0 = module.spoke_aws_r1_np_0.vpc.private_subnets,
#     spoke_aws_r1_np_1 = module.spoke_aws_r1_np_1.vpc.private_subnets,
#     spoke_aws_r2_np_2 = module.spoke_aws_r2_np_2.vpc.private_subnets,
#     spoke_aws_r1_p_0  = module.spoke_aws_r1_p_0.vpc.private_subnets,
#   }
# }
