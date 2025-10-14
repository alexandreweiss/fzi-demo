data "aviatrix_account" "aws" {
  account_name = var.aws_account
}

module "eks_runtimeA" {
  source                    = "./eks"
  cluster_name              = "eks-${var.aws_r1_location_short}-runtimeA"
  vpc_id                    = module.spoke_aws_r1_np_0.vpc.vpc_id
  private_subnet_ids        = module.spoke_aws_r1_np_0.vpc.private_subnets.*.subnet_id
  aviatrix_aws_account_arn  = data.aviatrix_account.aws.aws_role_arn
  control_plane_subnet_cidr = data.aws_subnet.control_plane_subnet_0.cidr_block
  depends_on                = [module.spoke_aws_r1_np_0]
}

# Data sources for EKS clusters
data "aws_eks_cluster" "runtimeA" {
  name = module.eks_runtimeA.eks.cluster_name
}

data "aws_eks_cluster_auth" "runtimeA" {
  name = module.eks_runtimeA.eks.cluster_name
}

# If you have a second cluster, add these:
# data "aws_eks_cluster" "runtimeB" {
#   name = module.eks_runtimeB.eks.cluster_name
# }

# data "aws_eks_cluster_auth" "runtimeB" {
#   name = module.eks_runtimeB.eks.cluster_name
# }

# Kubernetes providers with aliases
provider "kubernetes" {
  alias                  = "runtimeA"
  host                   = data.aws_eks_cluster.runtimeA.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.runtimeA.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.runtimeA.token
}

# provider "kubernetes" {
#   alias                  = "runtimeB"
#   host                   = data.aws_eks_cluster.runtimeB.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.runtimeB.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.runtimeB.token
# }

# Kubernetes resources for runtimeA cluster
resource "kubernetes_service_account" "avx_controller_runtimeA" {
  provider = kubernetes.runtimeA

  metadata {
    name      = "avx-controller"
    namespace = "kube-system"
  }
}

# Create the ServiceAccount token secret manually (required for K8s 1.24+)
resource "kubernetes_secret" "avx_controller_token_runtimeA" {
  provider = kubernetes.runtimeA

  metadata {
    name      = "avx-controller"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.avx_controller_runtimeA.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role" "avx_controller_runtimeA" {
  provider = kubernetes.runtimeA

  metadata {
    name = "avx-controller"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "namespaces", "nodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.aviatrix.com"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["events.k8s.io"]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "avx_controller_runtimeA" {
  provider = kubernetes.runtimeA

  metadata {
    name = "avx-controller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "avx-controller"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "avx-controller"
    namespace = "kube-system"
  }
}

# For a second cluster (runtimeB), you would add similar resources:
# resource "kubernetes_service_account" "avx_controller_runtimeB" {
#   provider = kubernetes.runtimeB
#   
#   metadata {
#     name      = "avx-controller"
#     namespace = "kube-system"
#   }
# }

# resource "kubernetes_cluster_role" "avx_controller_runtimeB" {
#   provider = kubernetes.runtimeB
#   # ... same configuration as runtimeA
# }

# resource "kubernetes_cluster_role_binding" "avx_controller_runtimeB" {
#   provider = kubernetes.runtimeB
#   # ... same configuration as runtimeA
# }

# Get the ServiceAccount token for kubeconfig
data "kubernetes_secret" "avx_controller_token" {
  provider = kubernetes.runtimeA

  metadata {
    name      = kubernetes_secret.avx_controller_token_runtimeA.metadata[0].name
    namespace = "kube-system"
  }

  depends_on = [kubernetes_secret.avx_controller_token_runtimeA]
}

# Generate kubeconfig file using the template
resource "local_file" "kubeconfig_avx" {
  filename = "${path.module}/kubeconfig-avx-controller"

  content = templatefile("${path.module}/kubeconfig", {
    ca_data      = data.aws_eks_cluster.runtimeA.certificate_authority[0].data
    endpoint     = data.aws_eks_cluster.runtimeA.endpoint
    cluster_name = data.aws_eks_cluster.runtimeA.name
    token        = data.kubernetes_secret.avx_controller_token.data["token"]
  })

  file_permission = "0600"
}

# Output the kubeconfig content for easy access
output "kubeconfig_content" {
  description = "Generated kubeconfig content for avx-controller"
  value = templatefile("${path.module}/kubeconfig", {
    ca_data      = data.aws_eks_cluster.runtimeA.certificate_authority[0].data
    endpoint     = data.aws_eks_cluster.runtimeA.endpoint
    cluster_name = data.aws_eks_cluster.runtimeA.name
    token        = data.kubernetes_secret.avx_controller_token.data["token"]
  })
  sensitive = true
}

resource "aviatrix_kubernetes_cluster" "eks_runtimeA_onboarding" {
  cluster_id  = module.eks_runtimeA.eks.cluster_arn
  kube_config = local_file.kubeconfig_avx.content
  cluster_details {
    account_name           = var.aws_account
    account_id             = data.aviatrix_account.aws.aws_account_number
    name                   = module.eks_runtimeA.eks.cluster_name
    region                 = var.aws_r1_location
    vpc_id                 = module.spoke_aws_r1_np_0.vpc.vpc_id
    is_publicly_accessible = true
    platform               = "EKS"
    version                = module.eks_runtimeA.eks.cluster_version
    network_mode           = "FLAT"
  }
}
