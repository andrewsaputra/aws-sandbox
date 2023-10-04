#######################
### SECURITY GROUPS ###

resource "aws_security_group" "eks_cluster" {
  name   = "${local.identifier}-eks-cluster"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.identifier}-eks-cluster"
  }
}

resource "aws_security_group_rule" "eks_cluster_egress_1" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.eks_cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "eks_cluster_ingress_1" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.eks_cluster.id
  self              = true
}


#######################
### CLOUDWATCH LOGS ###

resource "aws_cloudwatch_log_group" "app_cluster" {
  name              = "/aws/eks/${local.identifier}-cluster/cluster"
  retention_in_days = 3
}

###########
### EKS ###

resource "aws_eks_cluster" "app" {
  name     = "${local.identifier}-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  #version = "1.28"

  enabled_cluster_log_types = [
    "api",
    "audit",
  ]

  vpc_config {
    subnet_ids = data.terraform_remote_state.vpc.outputs.app_subnets
    security_group_ids = [
      aws_security_group.eks_cluster.id
    ]
  }

  depends_on = [
    aws_iam_role.eks_cluster_role,
    aws_cloudwatch_log_group.app_cluster,
  ]
}

resource "aws_eks_fargate_profile" "app" {
  cluster_name           = aws_eks_cluster.app.name
  fargate_profile_name   = "${local.identifier}-fargate-profile"
  pod_execution_role_arn = aws_iam_role.eks_fargate_pods.arn
  subnet_ids             = data.terraform_remote_state.vpc.outputs.app_subnets

  selector {
    namespace = "backend"

    labels = {
      app = local.identifier
    }
  }

  tags = {
    Name = "${local.identifier}-fargate-profile"
  }
}



# Required for Fargate only EKS
# https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html
resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.app.name
  fargate_profile_name   = "kube-system"
  pod_execution_role_arn = aws_iam_role.eks_fargate_pods.arn
  subnet_ids             = data.terraform_remote_state.vpc.outputs.app_subnets

  selector {
    namespace = "kube-system"

    #labels = {
    #  k8s-app : "kube-dns"
    #}
  }

  tags = {
    Name = "kube-system"
  }

  depends_on = [
    aws_eks_fargate_profile.app
  ]
}


resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.app.name
  addon_name                  = "coredns"
  addon_version               = "v1.10.1-eksbuild.3"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = jsonencode({
    computeType = "Fargate"
  })

  depends_on = [
    aws_eks_fargate_profile.kube_system
  ]
}



############################
### KUBERNETES RESOURCES ###

provider "kubernetes" {
  host                   = aws_eks_cluster.app.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.app.certificate_authority[0].data)

  # equal to : aws eks get-token --cluster-name <cluster-name>
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.app.name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.app.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.app.certificate_authority[0].data)

    # equal to : aws eks get-token --cluster-name <cluster-name>
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.app.name]
      command     = "aws"
    }
  }
}

######################
### ALB CONTROLLER ###
# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

data "tls_certificate" "app" {
  url = aws_eks_cluster.app.identity[0].oidc[0].issuer

  depends_on = [
    aws_eks_addon.coredns
  ]
}

resource "aws_iam_openid_connect_provider" "app" {
  url             = aws_eks_cluster.app.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.app.certificates[0].sha1_fingerprint]
}

resource "kubernetes_service_account_v1" "cluster" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }

  depends_on = [
    aws_iam_openid_connect_provider.app
  ]
}

resource "helm_release" "alb_controller" {
  name       = "alb-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  set {
    name  = "clusterName"
    type  = "string"
    value = aws_eks_cluster.app.name
  }

  set {
    name  = "serviceAccount.create"
    type  = "auto"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    type  = "string"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    type  = "string"
    value = data.aws_region.current.id
  }

  set {
    name  = "vpcId"
    type  = "string"
    value = data.terraform_remote_state.vpc.outputs.vpc_id
  }

  depends_on = [
    kubernetes_service_account_v1.cluster
  ]
}


###################
### APPLICATION ###

resource "kubernetes_namespace_v1" "backend" {
  metadata {
    name = "backend"
  }

  depends_on = [helm_release.alb_controller]
}

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = "${local.identifier}-deployment"
    namespace = "backend"
  }

  spec {
    selector {
      match_labels = {
        app = local.identifier
      }
    }

    replicas = 2

    template {
      metadata {
        name      = local.identifier
        namespace = "backend"

        labels = {
          app = local.identifier
        }
      }

      spec {
        container {
          name  = local.identifier
          image = "nginx"

          resources {
            limits = {
              cpu    = "250m"
              memory = "500M"
            }
          }

          port {
            container_port = 80
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].replicas
    ]
  }

  depends_on = [
    kubernetes_namespace_v1.backend
  ]
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = local.identifier
    namespace = "backend"
  }

  spec {
    type = "NodePort"

    selector = {
      app : local.identifier
    }

    port {
      port        = 80
      target_port = 80
    }
  }

  depends_on = [
    kubernetes_namespace_v1.backend
  ]
}

resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = local.identifier
    namespace = "backend"

    annotations = {
      "alb.ingress.kubernetes.io/load-balancer-name" : "${local.identifier}-lbext"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" : "ip"
      "alb.ingress.kubernetes.io/subnets" = join(",", data.terraform_remote_state.vpc.outputs.public_subnets)
    }
  }

  spec {
    ingress_class_name = "alb"
    default_backend {
      service {
        name = kubernetes_service_v1.app.metadata[0].name

        port {
          number = kubernetes_service_v1.app.spec[0].port[0].port
        }
      }
    }
  }
}


######################################
### METRICS SERVER AND AUTOSCALING ###
# https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"

  set {
    name  = "containerPort"
    type  = "auto"
    value = 4443
  }

  depends_on = [
    aws_iam_openid_connect_provider.app
  ]
}

resource "kubernetes_horizontal_pod_autoscaler_v1" "app" {
  metadata {
    name      = kubernetes_deployment_v1.app.metadata[0].name
    namespace = "backend"
  }

  spec {
    min_replicas                      = 1
    max_replicas                      = 3
    target_cpu_utilization_percentage = 70

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.app.metadata[0].name
    }
  }

  depends_on = [helm_release.metrics_server]
}

