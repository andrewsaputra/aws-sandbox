resource "random_id" "codepipeline_role" {
  byte_length = 8

  keepers = {
    Target = "iam-codepipeline-general"
  }

  prefix = "role-codepipeline-general-"
}

resource "aws_iam_role" "codepipeline" {
  name               = random_id.codepipeline_role.hex
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json

  inline_policy {
    name   = "permissions"
    policy = data.aws_iam_policy_document.codepipeline_policy.json
  }
}

data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


data "aws_iam_policy_document" "codepipeline_policy" {
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
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "codestar-connections:GetConnection",
      "codestar-connections:UseConnection",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${data.terraform_remote_state.global_s3.outputs.codepipeline_artifacts_arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    resources = ["*"]
  }
}
