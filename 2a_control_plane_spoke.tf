# Control plane spoke

data "aws_vpc" "control_plane_vpc" {
  filter {
    name   = "tag:Name"
    values = ["AviatrixVPC"]
  }
}

data "aws_subnets" "control_plane_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.control_plane_vpc.id]
  }
}

data "aws_subnet" "control_plane_subnet_0" {
  id = data.aws_subnets.control_plane_subnet.ids[0]
}

module "spoke_aws_r1_control_plane_0" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "8.0.0"

  cloud            = "AWS"
  name             = "ControlPlane"
  use_existing_vpc = true
  vpc_id           = data.aws_vpc.control_plane_vpc.id
  gw_subnet        = data.aws_subnet.control_plane_subnet_0.cidr_block
  region           = var.aws_r1_location
  account          = var.aws_account
  transit_gw       = module.backbone.transit.transit1a.transit_gateway.gw_name
  network_domain   = module.network_domains.network_domains[0]
  ha_gw            = false
  attached         = true
  single_ip_snat   = true
}

resource "aviatrix_gateway" "vpn_aws_r1_control_plane_0" {
  count = var.deploy_vpn_gateway ? 1 : 0

  cloud_type       = 1 # AWS
  account_name     = var.aws_account
  gw_name          = "${var.aws_r1_location_short}-control-plane-vpn"
  vpc_id           = data.aws_vpc.control_plane_vpc.id
  vpc_reg          = var.aws_r1_location
  gw_size          = "t3.small"
  subnet           = data.aws_subnet.control_plane_subnet_0.cidr_block
  vpn_cidr         = "10.44.10.0/24"
  additional_cidrs = "10.0.0.0/8"
  max_vpn_conn     = "100"
  split_tunnel     = true
  enable_vpn_nat   = true
  vpn_access       = "true"
  vpn_protocol     = "UDP"
}

resource "aviatrix_vpn_user" "aweiss" {

  user_email = "aweiss@aviatrix.com"
  user_name  = "aweiss"
  gw_name    = aviatrix_gateway.vpn_aws_r1_control_plane_0[0].gw_name
  vpc_id     = data.aws_vpc.control_plane_vpc.id
}
