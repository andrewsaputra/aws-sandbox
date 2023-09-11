###############################
### CODEDEPLOY SERVICE ROLE ###

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


#####################################
### CODEDEPLOY CROSS ACCOUNT ROLE ###

resource "random_id" "codedeploy_cross_account" {
  byte_length = 8

  keepers = {
    Target = "iam-codedeploy-cross-account"
  }

  prefix = "role-codedeploy-cross-account-"
}

resource "aws_iam_role" "codedeploy_cross_account" {
  name               = random_id.codedeploy_cross_account.hex
  assume_role_policy = data.aws_iam_policy_document.codedeploy_cross_account_assume_role.json

  inline_policy {
    name   = "permissions"
    policy = data.aws_iam_policy_document.codedeploy_cross_account_policy.json
  }
}

data "aws_iam_policy_document" "codedeploy_cross_account_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.cross_account_users
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "codedeploy_cross_account_policy" {
  statement {
    effect = "Allow"

    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${local.artifact_bucket}/*",
    ]
  }
}
