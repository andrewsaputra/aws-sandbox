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


###########
### EKS ###

resource "aws_eks_cluster" "app" {
  name     = "${local.identifier}-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = data.terraform_remote_state.vpc.outputs.app_subnets
    security_group_ids = [
      aws_security_group.eks_cluster.id
    ]
  }

  depends_on = [
    aws_iam_role.eks_cluster_role
  ]
}

resource "aws_eks_fargate_profile" "app" {
  cluster_name           = aws_eks_cluster.app.name
  fargate_profile_name   = "${local.identifier}-fargate-profile"
  pod_execution_role_arn = aws_iam_role.eks_fargate_pods.arn
  subnet_ids             = data.terraform_remote_state.vpc.outputs.app_subnets

  selector {
    namespace = "default"
  }
}

# Required for Fargate only EKS
# https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html
resource "aws_eks_fargate_profile" "coredns" {
  cluster_name           = aws_eks_cluster.app.name
  fargate_profile_name   = "CoreDNS"
  pod_execution_role_arn = aws_iam_role.eks_fargate_pods.arn
  subnet_ids             = data.terraform_remote_state.vpc.outputs.app_subnets

  selector {
    namespace = "kube-system"
    labels = {
      k8s-app : "kube-dns"
    }
  }

  depends_on = [
    aws_eks_fargate_profile.app
  ]
}