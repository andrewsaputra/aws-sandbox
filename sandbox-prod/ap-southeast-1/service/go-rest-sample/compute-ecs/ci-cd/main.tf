locals {

  identifier = "go-rest-sample"


  remote_state_backend         = "s3"
  remote_state_bucket          = "terraform-remote-backend-958954650561"
  remote_state_region          = "ap-southeast-1"
  remote_state_key_global_cicd = "global/iam/ci-cd/terraform.tfstate"
  remote_state_key_app         = "ap-southeast-1/service/go-rest-sample/compute-ecs/app/terraform.tfstate"

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
