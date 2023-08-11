locals {

  identifier = "go-rest-sample"

  app = {
    instance_type       = "t4g.nano"
    port                = 8080
    associate_public_ip = false
    artifact_kms_arn    = "arn:aws:kms:ap-southeast-1:199944304157:key/dfeca5b8-a63d-4ea9-9cd3-3e8b8d84498b"
    artifact_bucket     = "arn:aws:s3:::codepipeline-artifacts-b51cb22b9067cb07"

    ami = {
      owners = [
        "099720109477" #Canonical
      ]

      architecture   = "arm64"
      virtualization = "hvm"
      name           = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-*"
    }
  }

  alb = {
    port     = 80
    protocol = "HTTP"
    internal = false
  }

  target_group = {
    deregistration_delay = 120
    protocol             = "HTTP"

    health_check = {
      num_consecutive = 2
      interval        = 30
      timeout         = 5
      path            = "/health"
      port            = "traffic-port"
      protocol        = "HTTP"
      matcher         = "200-299"
    }
  }


  remote_state_backend       = "s3"
  remote_state_bucket        = "terraform-remote-backend-958954650561"
  remote_state_region        = "ap-southeast-1"
  remote_state_key_global_s3 = "global/s3/terraform.tfstate"
  remote_state_key_vpc       = "ap-southeast-1/vpc/vpc-prod/terraform.tfstate"

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

data "terraform_remote_state" "vpc" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_vpc
    region = local.remote_state_region
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

