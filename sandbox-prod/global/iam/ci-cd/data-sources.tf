locals {

  artifact_bucket = "arn:aws:s3:::codepipeline-artifacts-b51cb22b9067cb07"
  artifact_kms    = "arn:aws:kms:ap-southeast-1:199944304157:key/dfeca5b8-a63d-4ea9-9cd3-3e8b8d84498b"

  cross_account_users = [
    "arn:aws:iam::199944304157:root",
  ]

}

data "aws_caller_identity" "current" {}