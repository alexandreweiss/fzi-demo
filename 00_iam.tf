data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Aviatrix controller IP resolution
data "dns_a_record_set" "controller_ip" {
  host = var.controller_fqdn
}

# Retrieve Alex's ARN
# data "aws_iam_user" "aweiss" {
#   user_name = "AWSReservedSSO_SubAccountAdmin_0aaf0bb2c2c3052a"
# }

resource "aws_iam_user" "admin" {
  name          = "event-admin"
  force_destroy = true
}

resource "aws_iam_user_policy_attachment" "aws_admin" {
  user       = aws_iam_user.admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "null_resource" "admin_password" {
  provisioner "local-exec" {
    command     = var.use_profile ? local.local_deploy_command : local.cloud_deploy_command
    interpreter = ["/bin/bash", "-c"]
  }
}

locals {
  cloud_deploy_command = "echo Not implemented"
  # cloud_deploy_command = <<-EOT
  #   export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
  #   $(aws sts assume-role \
  #   --role-arn ${var.pod_arn} \
  #   --role-session-name MySessionName \
  #   --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
  #   --output text)) && \
  #   aws iam create-login-profile --user-name=${aws_iam_user.admin.name} --password=${var.admin_password} --no-password-reset-required \
  #   && unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  # EOT

  local_deploy_command = <<-EOT
    aws iam create-login-profile --user-name=${aws_iam_user.admin.name} --password=${var.admin_password} --no-password-reset-required --profile ${terraform.workspace}
  EOT
}

# EKS policy creation and assignment to Aviatrix role
data "aws_iam_policy_document" "k8s" {
  statement {
    effect = "Allow"

    actions = [
      "eks:ListClusters",
      "eks:DescribeCluster",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTags"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "k8s" {
  name   = "aviatrix-k8s"
  path   = "/"
  policy = data.aws_iam_policy_document.k8s.json
}

data "aws_iam_role" "avx" {
  name = "aviatrix-role-app"
}

resource "aws_iam_policy_attachment" "k8s" {
  name       = "aviatrix-k8s"
  roles      = [data.aws_iam_role.avx.name]
  policy_arn = aws_iam_policy.k8s.arn
}

# EKS access configuration for admin user
resource "aws_eks_access_entry" "eks_runtimeA" {
  cluster_name  = module.eks_runtimeA.eks.cluster_name
  principal_arn = aws_iam_user.admin.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_runtimeA" {
  cluster_name  = module.eks_runtimeA.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_user.admin.arn

  access_scope {
    type = "cluster"
  }
}

# resource "aws_eks_access_entry" "eks_runtimeA_human_admin" {
#   cluster_name  = module.eks_runtimeA.eks.cluster_name
#   principal_arn = var.human_admin_arn
#   type          = "STANDARD"
# }

# resource "aws_eks_access_policy_association" "eks_runtimeA_human_admin" {
#   cluster_name  = module.eks_runtimeA.eks.cluster_name
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#   principal_arn = var.human_admin_arn

#   access_scope {
#     type = "cluster"
#   }
# }
