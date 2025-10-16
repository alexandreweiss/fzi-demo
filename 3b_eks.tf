# Data sources for EKS clusters
data "aws_eks_cluster" "runtimeA" {
  count = var.get_eks_config ? 1 : 0

  name       = module.eks_runtimeA.eks.cluster_name
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

data "aws_eks_cluster_auth" "runtimeA" {
  count = var.get_eks_config ? 1 : 0

  name       = module.eks_runtimeA.eks.cluster_name
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# Kubernetes providers with aliases
# Manual uncomment after cluster creation
provider "kubernetes" {
  alias                  = "runtimeA"
  host                   = data.aws_eks_cluster.runtimeA[0].endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.runtimeA[0].certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.runtimeA[0].token
}


# Kubernetes resources for runtimeA cluster
resource "kubernetes_service_account" "avx_controller_runtimeA" {
  count = var.get_eks_config ? 1 : 0

  provider = kubernetes.runtimeA

  metadata {
    name      = "avx-controller"
    namespace = "kube-system"
  }
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# # Create the ServiceAccount token secret manually (required for K8s 1.24+)
resource "kubernetes_secret" "avx_controller_token_runtimeA" {
  count = var.get_eks_config ? 1 : 0

  provider = kubernetes.runtimeA

  metadata {
    name      = "avx-controller"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.avx_controller_runtimeA[0].metadata[0].name
    }
  }

  type       = "kubernetes.io/service-account-token"
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

resource "kubernetes_cluster_role" "avx_controller_runtimeA" {
  count = var.get_eks_config ? 1 : 0

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
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

resource "kubernetes_cluster_role_binding" "avx_controller_runtimeA" {
  count = var.get_eks_config ? 1 : 0

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
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# # Get the ServiceAccount token for kubeconfig
data "kubernetes_secret" "avx_controller_token" {
  count = var.get_eks_config ? 1 : 0

  provider = kubernetes.runtimeA

  metadata {
    name      = kubernetes_secret.avx_controller_token_runtimeA[0].metadata[0].name
    namespace = "kube-system"
  }

  depends_on = [kubernetes_secret.avx_controller_token_runtimeA, module.spoke_aws_r1_control_plane_0]
}

# # Generate kubeconfig file using the template
resource "local_file" "kubeconfig_avx" {
  count = var.get_eks_config ? 1 : 0

  filename = "${path.module}/kubeconfig-avx-controller"

  content = templatefile("${path.module}/kubeconfig", {
    ca_data      = data.aws_eks_cluster.runtimeA[0].certificate_authority[0].data
    endpoint     = data.aws_eks_cluster.runtimeA[0].endpoint
    cluster_name = "${data.aws_eks_cluster.runtimeA[0].name}-private"
    token        = data.kubernetes_secret.avx_controller_token[0].data["token"]
  })

  file_permission = "0600"
  depends_on      = [module.spoke_aws_r1_control_plane_0]
}

# Output the kubeconfig content for easy access
output "kubeconfig_content" {
  description = "Generated kubeconfig content for avx-controller"
  value = templatefile("${path.module}/kubeconfig", {
    ca_data      = data.aws_eks_cluster.runtimeA[0].certificate_authority[0].data
    endpoint     = data.aws_eks_cluster.runtimeA[0].endpoint
    cluster_name = "${data.aws_eks_cluster.runtimeA[0].name}-private"
    token        = data.kubernetes_secret.avx_controller_token[0].data["token"]
  })
  sensitive = true
}

resource "aviatrix_kubernetes_cluster" "eks_runtimeA_onboarding" {
  count = var.get_eks_config ? 1 : 0

  cluster_id  = "${module.eks_runtimeA.eks.cluster_arn}-private"
  kube_config = local_file.kubeconfig_avx[0].content
  cluster_details {
    account_name           = var.aws_account
    account_id             = data.aviatrix_account.aws.aws_account_number
    name                   = "${module.eks_runtimeA.eks.cluster_name}-private"
    region                 = var.aws_r1_location
    vpc_id                 = module.spoke_aws_r1_np_0.vpc.vpc_id
    is_publicly_accessible = true
    platform               = "EKS"
    version                = module.eks_runtimeA.eks.cluster_version
    network_mode           = "FLAT"
  }
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# # Nginx deployment with SSH and HTTP access
resource "kubernetes_deployment" "nginx_runtimeA" {
  provider = kubernetes.runtimeA

  metadata {
    name      = "nginx-runtimea"
    namespace = "default"
    labels = {
      app = "nginx-runtimea"
    }
  }

  spec {
    replicas = 4

    selector {
      match_labels = {
        app = "nginx-runtimea"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-runtimea"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"

          port {
            container_port = 80
            name           = "http"
          }

          port {
            container_port = 22
            name           = "ssh"
          }

          # Add SSH server to the nginx container
          command = ["/bin/bash"]
          args = ["-c", <<-EOF
            # Install SSH server
            apt-get update && apt-get install -y openssh-server
            # Create SSH user
            useradd -m -s /bin/bash sshuser
            echo 'sshuser:${var.admin_password}' | chpasswd
            # Configure SSH
            mkdir -p /var/run/sshd
            echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
            echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
            # Start SSH service in background
            /usr/sbin/sshd -D &
            # Start nginx in foreground
            nginx -g 'daemon off;'
          EOF
          ]

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# # Service to expose nginx deployment
resource "kubernetes_service" "nginx_runtimeA_service" {
  provider = kubernetes.runtimeA

  metadata {
    name      = "nginx-runtimea-service"
    namespace = "default"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-scheme"           = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-type"             = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"  = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-subnets"          = join(",", module.spoke_aws_r1_np_0.vpc.private_subnets.*.subnet_id)
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "tcp"
    }
  }

  spec {
    selector = {
      app = "nginx-runtimea"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    port {
      name        = "ssh"
      port        = 22
      target_port = 22
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# # Output the external IP/hostname of the load balancer
output "nginx_runtimeA_external_ip" {
  description = "External IP/hostname for nginx-runtimeA service"
  value       = kubernetes_service.nginx_runtimeA_service.status.0.load_balancer.0.ingress.0.hostname
}

output "nginx_runtimeA_access_info" {
  description = "Access information for nginx-runtimeA"
  value = {
    http_url     = "http://${kubernetes_service.nginx_runtimeA_service.status.0.load_balancer.0.ingress.0.hostname}"
    ssh_command  = "ssh sshuser@${kubernetes_service.nginx_runtimeA_service.status.0.load_balancer.0.ingress.0.hostname}"
    ssh_password = var.admin_password
  }
  sensitive = true
}

output "nginx_runtimeA_internal_ip" {
  description = "Internal cluster IP for nginx-runtimeA service"
  value       = kubernetes_service.nginx_runtimeA_service.spec.0.cluster_ip
}
