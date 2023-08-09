locals {

  cicd_kms_users = [
    data.terraform_remote_state.global_cicd.outputs.codepipeline_role_arn,
    data.terraform_remote_state.global_cicd.outputs.codebuild_role_arn,
    "arn:aws:iam::958954650561:root",
  ]


  remote_state_backend         = "s3"
  remote_state_bucket          = "terraform-remote-backend-199944304157"
  remote_state_region          = "ap-southeast-1"
  remote_state_key_global_cicd = "global/iam/ci-cd/terraform.tfstate"

}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "terraform_remote_state" "global_cicd" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_cicd
    region = local.remote_state_region
  }
}
