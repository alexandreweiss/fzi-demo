data "aviatrix_account" "aws" {
  account_name = var.aws_account
}

module "eks_runtimeA" {
  source                    = "./eks"
  cluster_name              = "eks-${var.aws_r1_location_short}-runtimeA"
  vpc_id                    = module.spoke_aws_r1_np_0.vpc.vpc_id
  private_subnet_ids        = module.spoke_aws_r1_np_0.vpc.private_subnets.*.subnet_id
  aviatrix_aws_account_arn  = data.aviatrix_account.aws.aws_role_arn
  control_plane_subnet_cidr = [data.aws_subnet.control_plane_subnet_0.cidr_block, "192.168.16.0/24"]
  # depends_on                = [module.spoke_aws_r1_np_0, aviatrix_gateway.vpn_aws_r1_control_plane_0, aviatrix_vpn_user.aweiss]
  depends_on = [module.spoke_aws_r1_np_0, module.spoke_aws_r1_control_plane_0, module.backbone, module.network_domains, aws_iam_user.admin]
}
