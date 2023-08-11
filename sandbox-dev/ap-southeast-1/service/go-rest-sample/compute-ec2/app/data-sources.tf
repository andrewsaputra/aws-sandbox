locals {

  identifier = "go-rest-sample"

  app = {
    instance_type       = "t4g.nano"
    port                = 8080
    associate_public_ip = false

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
  remote_state_bucket        = "terraform-remote-backend-199944304157"
  remote_state_region        = "ap-southeast-1"
  remote_state_key_global_s3 = "global/s3/terraform.tfstate"
  remote_state_key_vpc       = "ap-southeast-1/vpc/vpc-dev/terraform.tfstate"
  remote_state_key_kms       = "ap-southeast-1/kms/terraform.tfstate"

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

data "terraform_remote_state" "kms" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_kms
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

