locals {

  identifier = "go-rest-sample"

  codebuild = {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    container    = "LINUX_CONTAINER"
  }


  remote_state_backend         = "s3"
  remote_state_bucket          = "terraform-remote-backend-958954650561"
  remote_state_region          = "ap-southeast-1"
  remote_state_key_global_cicd = "global/iam/ci-cd/terraform.tfstate"
  remote_state_key_app         = "ap-southeast-1/service/go-rest-sample/compute-apprunner/app/terraform.tfstate"

}

data "terraform_remote_state" "global_cicd" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_cicd
    region = local.remote_state_region
  }
}

data "terraform_remote_state" "app" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_app
    region = local.remote_state_region
  }
}

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
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.release_log.name
    }
  }

  cache {
    type = "NO_CACHE"
  }

  tags = {
    Name = "${local.identifier}-release"
  }
}
