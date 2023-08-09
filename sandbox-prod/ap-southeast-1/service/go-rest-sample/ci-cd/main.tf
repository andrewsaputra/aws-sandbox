locals {

  identifier = "go-rest-sample"


  remote_state_backend         = "s3"
  remote_state_bucket          = "terraform-remote-backend-958954650561"
  remote_state_region          = "ap-southeast-1"
  remote_state_key_global_cicd = "global/iam/ci-cd/terraform.tfstate"

}

data "terraform_remote_state" "global_cicd" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_cicd
    region = local.remote_state_region
  }
}


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
