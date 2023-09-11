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

  # https://docs.aws.amazon.com/codebuild/latest/userguide/auth-and-access-control-iam-identity-based-access-control.html#customer-managed-policies-example-create-vpc-network-interface
  statement {
    sid    = "CodebuildWithVPC"
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterfacePermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values = [
        "codebuild.amazonaws.com"
      ]
    }

    resources = ["*"]
  }

  statement {
    sid    = "AccessCodepipelineArtifacts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${data.terraform_remote_state.global_s3.outputs.codepipeline_artifacts_arn}/*",
    ]
  }

  # https://developer.hashicorp.com/packer/plugins/builders/amazon#iam-task-or-instance-role
  statement {
    sid    = "PackerPermissions"
    effect = "Allow"

    actions = [
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CopyImage",
      "ec2:CreateImage",
      "ec2:CreateKeyPair",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteKeyPair",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSnapshot",
      "ec2:DeleteVolume",
      "ec2:DeregisterImage",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeRegions",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSnapshots",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DetachVolume",
      "ec2:GetPasswordData",
      "ec2:ModifyImageAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySnapshotAttribute",
      "ec2:RegisterImage",
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  # https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push.html#image-push-iam
  statement {
    sid    = "ECRPermissions"
    effect = "Allow"

    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
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
}
