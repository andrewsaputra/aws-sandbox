################
### IAM ROLE ###

# https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html
resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-role-${local.identifier}"
  assume_role_policy = data.aws_iam_policy_document.assume_eks_cluster_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
  ]
}

data "aws_iam_policy_document" "assume_eks_cluster_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


# https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html#eks-launch-workers
resource "aws_iam_role" "eks_fargate_pods" {
  name               = "eks-fargate-pods-${local.identifier}"
  assume_role_policy = data.aws_iam_policy_document.assume_eks_fargate_pods_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy",
  ]
}

data "aws_iam_policy_document" "assume_eks_fargate_pods_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "alb_controller" {
  name               = "eks-alb-controller-${local.identifier}"
  assume_role_policy = data.aws_iam_policy_document.assume_alb_controller_role.json

  inline_policy {
    name   = "permissions"
    policy = file("alb-controller-policy.json")
  }
}

data "aws_iam_policy_document" "assume_alb_controller_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.app.id]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${aws_iam_openid_connect_provider.app.url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${aws_iam_openid_connect_provider.app.url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}
