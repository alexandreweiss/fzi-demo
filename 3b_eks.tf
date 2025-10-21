# Data sources for EKS clusters
data "aws_eks_cluster" "runtimeA" {
  name       = module.eks_runtimeA.eks.cluster_name
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

data "aws_eks_cluster_auth" "runtimeA" {
  name       = module.eks_runtimeA.eks.cluster_name
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# Kubernetes providers with aliases
# Manual uncomment after cluster creation
provider "kubernetes" {
  alias                  = "runtimeA"
  host                   = data.aws_eks_cluster.runtimeA.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.runtimeA.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.runtimeA.token
}


# Kubernetes resources for runtimeA cluster
resource "kubernetes_service_account" "avx_controller_runtimeA" {
  provider = kubernetes.runtimeA

  metadata {
    name      = "avx-controller"
    namespace = "kube-system"
  }
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# # Create the ServiceAccount token secret manually (required for K8s 1.24+)
resource "kubernetes_secret" "avx_controller_token_runtimeA" {
  provider = kubernetes.runtimeA

  metadata {
    name      = "avx-controller"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.avx_controller_runtimeA.metadata[0].name
    }
  }

  type       = "kubernetes.io/service-account-token"
  depends_on = [module.spoke_aws_r1_control_plane_0]
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
  depends_on = [module.spoke_aws_r1_control_plane_0]
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
  depends_on = [module.spoke_aws_r1_control_plane_0]
}

resource "kubernetes_cluster_role" "view_nodes" {
  provider = kubernetes.runtimeA

  metadata {
    name = "view-nodes"
  }
  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["nodes"]
  }
  # The following 2 rules have to be added
  rule {
    verbs      = ["create", "patch"]
    api_groups = ["events.k8s.io"]
    resources  = ["events"]
  }
  rule {
    verbs      = ["*"]
    api_groups = ["networking.aviatrix.com"]
    resources  = ["webgrouppolicies", "webgrouppolicies/status"]
  }
}

# # Get the ServiceAccount token for kubeconfig
data "kubernetes_secret" "avx_controller_token" {
  provider = kubernetes.runtimeA

  metadata {
    name      = kubernetes_secret.avx_controller_token_runtimeA.metadata[0].name
    namespace = "kube-system"
  }

  depends_on = [kubernetes_secret.avx_controller_token_runtimeA, module.spoke_aws_r1_control_plane_0]
}

# # Generate kubeconfig file using the template
resource "local_file" "kubeconfig_avx" {
  filename = "${path.module}/kubeconfig-avx-controller"

  content = templatefile("${path.module}/kubeconfig", {
    ca_data      = data.aws_eks_cluster.runtimeA.certificate_authority[0].data
    endpoint     = data.aws_eks_cluster.runtimeA.endpoint
    cluster_name = "${data.aws_eks_cluster.runtimeA.name}-private"
    token        = data.kubernetes_secret.avx_controller_token.data["token"]
  })

  file_permission = "0600"
  depends_on      = [module.spoke_aws_r1_control_plane_0]
}

# Output the kubeconfig content for easy access
output "kubeconfig_content" {
  description = "Generated kubeconfig content for avx-controller"
  value = templatefile("${path.module}/kubeconfig", {
    ca_data      = data.aws_eks_cluster.runtimeA.certificate_authority[0].data
    endpoint     = data.aws_eks_cluster.runtimeA.endpoint
    cluster_name = "${data.aws_eks_cluster.runtimeA.name}-private"
    token        = data.kubernetes_secret.avx_controller_token.data["token"]
  })
  sensitive = true
}

resource "aviatrix_kubernetes_cluster" "eks_runtimeA_onboarding" {
  cluster_id  = "${module.eks_runtimeA.eks.cluster_arn}-private"
  kube_config = local_file.kubeconfig_avx.content
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

# Create an Aviatrix Smart Group that matches the K8S nginx service
resource "aviatrix_smart_group" "nginx_runtimeA_smart_group" {
  name = "nginx-runtimeA-sg"
  selector {
    match_expressions {
      type           = "k8s"
      k8s_cluster_id = module.eks_runtimeA.eks.cluster_arn
      k8s_namespace  = "default"
      k8s_service    = "nginx-runtimea-service"
    }
  }
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

# Apply Aviatrix WebGroupPolicies CustomResourceDefinition
resource "kubernetes_manifest" "aviatrix_webgrouppolicies_crd_runtimeA" {
  provider = kubernetes.runtimeA

  manifest = {
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"

    metadata = {
      annotations = {
        "controller-gen.kubebuilder.io/version" = "v0.14.0"
      }
      name = "webgrouppolicies.networking.aviatrix.com"
    }

    spec = {
      group = "networking.aviatrix.com"
      names = {
        kind     = "WebGroupPolicy"
        listKind = "WebGroupPolicyList"
        plural   = "webgrouppolicies"
        singular = "webgrouppolicy"
      }
      scope = "Namespaced"
      versions = [
        {
          name = "v1alpha1"
          schema = {
            openAPIV3Schema = {
              description = "WebGroupPolicy is the Schema for the webgrouppolicies API"
              properties = {
                apiVersion = {
                  description = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources"
                  type        = "string"
                }
                kind = {
                  description = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds"
                  type        = "string"
                }
                metadata = {
                  type = "object"
                }
                spec = {
                  description = "WebGroupPolicySpec defines the desired state of WebGroupPolicy"
                  properties = {
                    allowedDomains = {
                      items = {
                        type = "string"
                      }
                      type = "array"
                    }
                    apiCategory = {
                      enum = [
                        "BLOCK_ALL",
                        "ALLOW_ALL",
                        "FILTER"
                      ]
                      type = "string"
                    }
                    target = {
                      properties = {
                        type = {
                          enum = [
                            "namespace",
                            "service"
                          ]
                          type = "string"
                        }
                      }
                      required = ["type"]
                      type     = "object"
                    }
                  }
                  required = ["allowedDomains", "apiCategory", "target"]
                  type     = "object"
                }
                status = {
                  properties = {
                    appDomainUuid = {
                      type = "string"
                    }
                    policyUuid = {
                      type = "string"
                    }
                    targetSmartGroupUuid = {
                      type = "string"
                    }
                  }
                  type = "object"
                }
              }
              required = ["spec"]
              type     = "object"
            }
          }
          served  = true
          storage = true
          subresources = {
            status = {}
          }
        }
      ]
    }
  }

  depends_on = [module.spoke_aws_r1_control_plane_0]
}

# Apply WebGroupPolicy instance to the cluster
resource "kubernetes_manifest" "webgrouppolicy_runtimeA" {
  provider = kubernetes.runtimeA

  manifest = {
    apiVersion = "networking.aviatrix.com/v1alpha1"
    kind       = "WebGroupPolicy"

    metadata = {
      name      = "webgrouppolicy-sample"
      namespace = "default"
    }

    spec = {
      allowedDomains = [
        "monip.org"
      ]
      apiCategory = "FILTER"
      target = {
        type = "namespace"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.aviatrix_webgrouppolicies_crd_runtimeA,
    module.spoke_aws_r1_control_plane_0
  ]
}
