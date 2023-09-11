###############################
### CODEBUILD SERVICE ROLE ###

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
    sid    = "CreateCloudwatchLogs"
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
    sid    = "BasicEC2Permissions"
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
    sid    = "AppRunnerPermissions"
    effect = "Allow"

    actions = [
      "apprunner:StartDeployment",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AccessArtifactBucket"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${local.artifact_bucket}/*",
    ]
  }

  statement {
    sid    = "UseKMS"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      local.artifact_kms,
    ]
  }
}


#####################################
### CODEBUILD CROSS ACCOUNT ROLE ###

resource "random_id" "codebuild_cross_account" {
  byte_length = 8

  keepers = {
    Target = "iam-codebuild-cross-account"
  }

  prefix = "role-codebuild-cross-account-"
}

resource "aws_iam_role" "codebuild_cross_account" {
  name               = random_id.codebuild_cross_account.hex
  assume_role_policy = data.aws_iam_policy_document.codebuild_cross_account_assume_role.json

  inline_policy {
    name   = "permissions"
    policy = data.aws_iam_policy_document.codebuild_cross_account_policy.json
  }
}

data "aws_iam_policy_document" "codebuild_cross_account_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.cross_account_users
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "codebuild_cross_account_policy" {
  statement {
    effect = "Allow"

    actions = [
      "codebuild:StartBuild",
      "codebuild:StartBuildBatch",
      "codebuild:BatchGetBuilds",
    ]

    resources = ["*"]
  }
}
