locals {

  remote_state_backend       = "s3"
  remote_state_bucket        = "terraform-remote-backend-958954650561"
  remote_state_region        = "ap-southeast-1"
  remote_state_key_global_s3 = "global/s3/terraform.tfstate"

}


data "aws_caller_identity" "current" {}

data "terraform_remote_state" "global_s3" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_s3
    region = local.remote_state_region
  }
}
