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

resource "aws_security_group" "codebuild" {
  name   = "${local.identifier}-codebuild"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.identifier}-codebuild"
  }
}

resource "aws_codebuild_project" "release" {
  name         = "${local.identifier}-release"
  service_role = data.terraform_remote_state.global_cicd.outputs.codebuild_role_arn

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile("buildspec-release.yml", {
      ecr_image : data.terraform_remote_state.ecr.outputs.repository_url
      ecr_auth_endpoint : data.terraform_remote_state.ecr.outputs.auth_endpoint
      application_arn : data.terraform_remote_state.app.outputs.apprunner_arn
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
    privileged_mode             = local.codebuild.privileged_mode
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

  # avoid using codebuild's default shared ips to pull images from dockerhub : https://www.docker.com/increase-rate-limit
  vpc_config {
    vpc_id  = data.terraform_remote_state.vpc.outputs.vpc_id
    subnets = data.terraform_remote_state.vpc.outputs.app_subnets
    security_group_ids = [
      aws_security_group.codebuild.id
    ]
  }

  tags = {
    Name = "${local.identifier}-release"
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
        BranchName       = local.release_branch
      }
    }
  }

  stage {
    name = "Deploy-Pre-Production"

    action {
      name             = "Build-and-Deploy"
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
    name = "Deploy-Production"

    action {
      name            = "Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["BuildOutputArtifact"]

      configuration = {
        ProjectName = local.cd_production.codebuild_name
      }

      role_arn = local.cd_production.codebuild_cross_account_role
    }
  }
}
