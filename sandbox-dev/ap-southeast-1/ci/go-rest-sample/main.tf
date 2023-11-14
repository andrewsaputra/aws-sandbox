####################
### DATA SOURCES ###
data "terraform_remote_state" "global_cicd" {
  backend = var.remote_state_backend

  config = {
    bucket = var.remote_state_bucket
    key    = var.remote_state_key_global_cicd
    region = var.remote_state_region
  }
}


###########################
### CODEBUILD LOG GROUP ###
resource "aws_cloudwatch_log_group" "this" {
  name              = "codebuild-ci-${var.stack_identifier}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "codebuild-ci-${var.stack_identifier}"
  }
}


#################
### CODEBUILD ###
resource "aws_codebuild_project" "this" {
  name         = "ci-${var.stack_identifier}"
  service_role = data.terraform_remote_state.global_cicd.outputs.codebuild_role_arn

  source {
    type            = "GITHUB"
    location        = var.repository_url
    git_clone_depth = 1
    buildspec       = file("buildspec.yml")
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = var.codebuild_specs.compute_type
    image                       = var.codebuild_specs.image
    image_pull_credentials_type = "CODEBUILD"
    type                        = var.codebuild_specs.container
    privileged_mode             = var.codebuild_specs.privileged_mode

    environment_variable {
      name  = "GOMODCACHE"
      value = "/tmp/go/pkg/mod"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.this.name
    }
  }

  # ec2 only options
  #cache {
  #  type  = "LOCAL"
  #  modes = ["LOCAL_CUSTOM_CACHE", "LOCAL_SOURCE_CACHE"]
  #}

  tags = {
    Name = "ci-${var.stack_identifier}"
  }

  lifecycle {
    ignore_changes = ["queued_timeout", "build_timeout"] # prevent state updates due to default values (unsupported for lambda containers)
  }
}

resource "aws_codebuild_webhook" "this" {
  project_name = aws_codebuild_project.this.name
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
