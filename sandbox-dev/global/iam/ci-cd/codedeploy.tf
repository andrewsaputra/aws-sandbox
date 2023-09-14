resource "random_id" "codedeploy" {
  byte_length = 8

  keepers = {
    Target = "iam-codedeploy-general"
  }

  prefix = "role-codedeploy-general-"
}

resource "aws_iam_role" "codedeploy" {
  name               = random_id.codedeploy.hex
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole",
    "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS",
  ]

  inline_policy {
    name   = "permissions"
    policy = data.aws_iam_policy_document.codedeploy_policy.json
  }
}

data "aws_iam_policy_document" "codedeploy_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "codedeploy_policy" {
  statement {
    sid    = "UseKMS"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      "*",
    ]
  }
}