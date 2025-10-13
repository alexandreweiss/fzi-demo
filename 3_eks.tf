data "aviatrix_account" "aws" {
  account_name = var.aws_account
}

module "eks_runtimeA" {
  source                   = "./eks"
  cluster_name             = "eks-${var.aws_r1_location_short}-runtimeA"
  vpc_id                   = module.spoke_aws_r1_np_0.vpc.vpc_id
  private_subnet_ids       = module.spoke_aws_r1_np_0.vpc.private_subnets.*.subnet_id
  aviatrix_aws_account_arn = data.aviatrix_account.aws.aws_role_arn
  depends_on               = [module.spoke_aws_r1_np_0]
}
