stack_identifier   = "go-rest-sample"
repository_url     = "https://github.com/andrewsaputra/go-rest-sample"
log_retention_days = 3
codebuild_specs = {
  compute_type    = "BUILD_LAMBDA_4GB"
  image           = "aws/codebuild/amazonlinux-aarch64-lambda-standard:go1.21"
  container       = "ARM_LAMBDA_CONTAINER"
  privileged_mode = false
}

remote_state_backend         = "s3"
remote_state_bucket          = "terraform-remote-backend-199944304157"
remote_state_region          = "ap-southeast-1"
remote_state_key_global_cicd = "global/iam/ci-cd/terraform.tfstate"
