locals {

  identifier = "go-rest-sample"

  repository_name = "andrewsaputra/go-rest-sample"
  repository_url  = "https://github.com/${local.repository_name}"

  codebuild = {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    container    = "LINUX_CONTAINER"
  }

  cd_production = {
    cd_app_name           = "go-rest-sample-release"
    cd_group_name         = "go-rest-sample-release-group"
    cd_cross_account_role = "arn:aws:iam::958954650561:role/role-codedeploy-cross-account-dee75eeb7f56aaa8"
  }


  remote_state_backend         = "s3"
  remote_state_bucket          = "terraform-remote-backend-199944304157"
  remote_state_region          = "ap-southeast-1"
  remote_state_key_global_s3   = "global/s3/terraform.tfstate"
  remote_state_key_global_cicd = "global/iam/ci-cd/terraform.tfstate"
  remote_state_key_kms         = "ap-southeast-1/kms/terraform.tfstate"

}


data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "terraform_remote_state" "global_s3" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_s3
    region = local.remote_state_region
  }
}

data "terraform_remote_state" "global_cicd" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_cicd
    region = local.remote_state_region
  }
}

data "terraform_remote_state" "kms" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_kms
    region = local.remote_state_region
  }
}
