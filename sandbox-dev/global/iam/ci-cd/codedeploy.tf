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
  ]
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
