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
    type      = "CODEPIPELINE"
    buildspec = file("buildspec-release.yml")
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


##################
### CODEDEPLOY ###

resource "aws_codedeploy_app" "release" {
  name             = "${local.identifier}-release"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "release" {
  app_name               = aws_codedeploy_app.release.name
  deployment_group_name  = "${local.identifier}-release-group"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  service_role_arn       = data.terraform_remote_state.global_cicd.outputs.codedeploy_role_arn

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "${local.identifier}-app"
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
      name             = "BuildAction"
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
    name = "Deploy-Pre-Production"

    action {
      name            = "DeployAction"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildOutputArtifact"]

      configuration = {
        ApplicationName     = aws_codedeploy_deployment_group.release.app_name
        DeploymentGroupName = aws_codedeploy_deployment_group.release.deployment_group_name
      }
    }
  }

  stage {
    name = "Deploy-Production"

    action {
      name            = "DeployAction"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildOutputArtifact"]

      configuration = {
        ApplicationName     = local.cd_production.cd_app_name
        DeploymentGroupName = local.cd_production.cd_group_name
      }

      role_arn = local.cd_production.cd_cross_account_role
    }
  }
}
