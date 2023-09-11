terraform {
  required_version = "~> 1.5.4"

  backend "s3" {
    bucket         = "terraform-remote-backend-958954650561"
    dynamodb_table = "terraform-remote-backend-958954650561"
    key            = "ap-southeast-1/service/go-rest-sample/compute-apprunner/app/route53/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}