locals {

  identifier     = "go-rest-sample"
  route53_domain = "dev.zenithbytes.xyz"

  app = {
    cpu_units    = 256
    memory_units = 512
    port         = 8080

    scaling_policy = {
      min_size        = 1
      max_size        = 10
      max_concurrency = 100
    }

    health_check = {
      num_consecutive = 2
      interval        = 10
      timeout         = 5
      path            = "/health"
      protocol        = "HTTP"
    }
  }

  alb = {
    port       = 443
    protocol   = "HTTPS"
    internal   = false
    ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  }

  target_group = {
    deregistration_delay = 120
    protocol             = "HTTP"
    target_type          = "ip"

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


  remote_state_backend            = "s3"
  remote_state_bucket             = "terraform-remote-backend-199944304157"
  remote_state_region             = "ap-southeast-1"
  remote_state_key_vpc            = "ap-southeast-1/vpc/vpc-dev/terraform.tfstate"
  remote_state_key_ecr            = "ap-southeast-1/service/go-rest-sample/compute-ecs/ecr/terraform.tfstate"
  remote_state_key_global_route53 = "global/route53/terraform.tfstate"
  remote_state_key_global_s3      = "global/s3/terraform.tfstate"

}

data "aws_region" "current" {}


data "terraform_remote_state" "vpc" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_vpc
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

data "terraform_remote_state" "global_route53" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_route53
    region = local.remote_state_region
  }
}

data "terraform_remote_state" "global_s3" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_s3
    region = local.remote_state_region
  }
}