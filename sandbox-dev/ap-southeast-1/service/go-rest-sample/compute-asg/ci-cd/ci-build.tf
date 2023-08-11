###########################
### CODEBUILD LOG GROUP ###

resource "aws_cloudwatch_log_group" "ci_log" {
  name              = "codebuild-${local.identifier}-ci"
  retention_in_days = 3

  tags = {
    Name = "codebuild-${local.identifier}-ci"
  }
}


#################
### CODEBUILD ###

resource "aws_codebuild_project" "ci" {
  name         = "${local.identifier}-ci"
  service_role = data.terraform_remote_state.global_cicd.outputs.codebuild_role_arn

  source {
    type            = "GITHUB"
    location        = local.repository_url
    git_clone_depth = 1
    buildspec       = file("buildspec-ci.yml")
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = local.codebuild.compute_type
    image                       = local.codebuild.image
    image_pull_credentials_type = "CODEBUILD"
    type                        = local.codebuild.container
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.ci_log.name
    }
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_CUSTOM_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  tags = {
    Name = "${local.identifier}-ci"
  }
}

resource "aws_codebuild_webhook" "ci" {
  project_name = aws_codebuild_project.ci.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED,PULL_REQUEST_UPDATED"
    }
  }

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/main"
    }
  }
}
