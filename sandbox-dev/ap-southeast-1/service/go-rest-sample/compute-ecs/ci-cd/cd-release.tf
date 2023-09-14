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


##################
### CODEDEPLOY ###

resource "aws_codedeploy_app" "release" {
  name             = "${local.identifier}-release"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "release" {
  app_name               = aws_codedeploy_app.release.name
  deployment_group_name  = "${local.identifier}-release-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = data.terraform_remote_state.global_cicd.outputs.codedeploy_role_arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
    }
  }

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  ecs_service {
    cluster_name = data.terraform_remote_state.app.outputs.app_cluster_name
    service_name = data.terraform_remote_state.app.outputs.app_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          data.terraform_remote_state.app.outputs.alb_listener
        ]
      }

      target_group {
        name = data.terraform_remote_state.app.outputs.blue_target_group_name
      }

      target_group {
        name = data.terraform_remote_state.app.outputs.green_target_group_name
      }
    }
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
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceOutputArtifact"]
      output_artifacts = [
        "BuildOutputArtifactDev",
        "BuildOutputArtifactProd",
      ]

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
      input_artifacts = ["BuildOutputArtifactDev"]

      configuration = {
        ApplicationName     = aws_codedeploy_deployment_group.release.app_name
        DeploymentGroupName = aws_codedeploy_deployment_group.release.deployment_group_name
      }
    }
  }

  stage {
    name = "Deploy-Production"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildOutputArtifactProd"]

      configuration = {
        ApplicationName     = local.cd_production.codedeploy_app_name
        DeploymentGroupName = local.cd_production.codedeploy_group_name
      }

      role_arn = local.cd_production.codedeploy_cross_account_role
    }
  }
}
