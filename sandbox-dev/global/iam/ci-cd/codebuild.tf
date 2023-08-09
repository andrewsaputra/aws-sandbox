resource "random_id" "codebuild" {
  byte_length = 8

  keepers = {
    Target = "iam-codebuild-general"
  }

  prefix = "role-codebuild-general-"
}

resource "aws_iam_role" "codebuild" {
  name               = random_id.codebuild.hex
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json

  inline_policy {
    name   = "permissions"
    policy = data.aws_iam_policy_document.codebuild_policy.json
  }
}

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect = "Allow"

    actions = [
      #"logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:codebuild-*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${data.terraform_remote_state.global_s3.outputs.codepipeline_artifacts_arn}/*",
    ]
  }
}