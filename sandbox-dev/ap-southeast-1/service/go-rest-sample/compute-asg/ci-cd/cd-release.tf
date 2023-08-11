###########################
### CODEBUILD LOG GROUP ###

resource "aws_cloudwatch_log_group" "release_log" {
  name              = "codebuild-${local.identifier}-release"
  retention_in_days = 3

  tags = {
    Name = "codebuild-${local.identifier}-release"
  }
}


#################
### CODEBUILD ###

resource "aws_codebuild_project" "release" {
  name         = "${local.identifier}-release"
  service_role = data.terraform_remote_state.global_cicd.outputs.codebuild_role_arn

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile("buildspec-release.yml", {
      packer_binary : local.packer_binary
      ami_filename : local.ami_filename
    })
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = local.codebuild.compute_type
    image                       = local.codebuild.image
    image_pull_credentials_type = "CODEBUILD"
    type                        = local.codebuild.container
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.release_log.name
    }
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_CUSTOM_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  tags = {
    Name = "${local.identifier}-release"
  }
}


###############################
### LAMBDA RELEASE FUNCTION ###

resource "aws_iam_role" "lambda" {
  name               = "lambda-role-${local.identifier}-release"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ]

  inline_policy {
    name   = "permissions"
    policy = data.aws_iam_policy_document.lambda_policy.json
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

// https://docs.aws.amazon.com/lambda/latest/dg/services-codepipeline.html#services-codepipeline-permissions
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"

    actions = [
      "codepipeline:PutJobFailureResult",
      "codepipeline:PutJobSuccessResult",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:ModifyLaunchTemplate",
      "autoscaling:StartInstanceRefresh",
    ]

    resources = ["*"]
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda-code/bootstrap"
  output_path = "${path.module}/lambda-code/handler.zip"
}

# https://docs.aws.amazon.com/lambda/latest/dg/golang-package.html
resource "aws_lambda_function" "lambda" {
  function_name    = "${local.identifier}-release"
  role             = aws_iam_role.lambda.arn
  filename         = "${path.module}/lambda-code/handler.zip"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "bootstrap"
  runtime          = "provided.al2"
  architectures    = ["arm64"]
  memory_size      = 128

  environment {
    variables = {
      "func_AutoScalingGroup"    = data.terraform_remote_state.app.outputs.asg_name
      "func_LaunchTemplateId"    = data.terraform_remote_state.app.outputs.launch_template_id
      "func_ArtifactAmiFilename" = local.ami_filename
      "func_ArtifactAmiRegion"   = data.aws_region.current.name
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_release_log" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 3

  tags = {
    Name = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  }
}


####################
### CODEPIPELINE ###

resource "aws_codepipeline" "pipeline" {
  name     = "${local.identifier}-release"
  role_arn = data.terraform_remote_state.global_cicd.outputs.codepipeline_role_arn

  artifact_store {
    type     = "S3"
    location = data.terraform_remote_state.global_s3.outputs.codepipeline_artifacts_bucket
    encryption_key {
      id   = data.terraform_remote_state.kms.outputs.kms_cicd_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutputArtifact"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.release.arn
        FullRepositoryId = local.repository_name
        BranchName       = "test-release"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutputArtifact"]
      output_artifacts = ["BuildOutputArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.release.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Refresh-ASG"
      category        = "Invoke"
      owner           = "AWS"
      provider        = "Lambda"
      version         = "1"
      input_artifacts = ["BuildOutputArtifact"]

      configuration = {
        FunctionName = aws_lambda_function.lambda.function_name
      }
    }
  }
}
