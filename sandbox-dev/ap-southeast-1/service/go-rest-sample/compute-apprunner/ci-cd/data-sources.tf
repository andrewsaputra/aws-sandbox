locals {

  identifier = "go-rest-sample"

  repository_name = "andrewsaputra/go-rest-sample"
  repository_url  = "https://github.com/${local.repository_name}"
  release_branch  = "test-release"

  codebuild = {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    container       = "LINUX_CONTAINER"
    privileged_mode = true
  }

  cd_production = {
    codebuild_name               = "go-rest-sample-release"
    codebuild_cross_account_role = "arn:aws:iam::958954650561:role/role-codebuild-cross-account-8dd5ede9e437621b"
  }


  remote_state_backend         = "s3"
  remote_state_bucket          = "terraform-remote-backend-199944304157"
  remote_state_region          = "ap-southeast-1"
  remote_state_key_global_s3   = "global/s3/terraform.tfstate"
  remote_state_key_global_cicd = "global/iam/ci-cd/terraform.tfstate"
  remote_state_key_kms         = "ap-southeast-1/kms/terraform.tfstate"
  remote_state_key_vpc         = "ap-southeast-1/vpc/vpc-dev/terraform.tfstate"
  remote_state_key_app         = "ap-southeast-1/service/go-rest-sample/compute-apprunner/app/terraform.tfstate"
  remote_state_key_ecr         = "ap-southeast-1/service/go-rest-sample/compute-apprunner/ecr/terraform.tfstate"

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

data "terraform_remote_state" "vpc" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_vpc
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

data "terraform_remote_state" "ecr" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_ecr
    region = local.remote_state_region
  }
}