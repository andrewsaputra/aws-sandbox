terraform {
  required_version = "~> 1.5.4"

  backend "s3" {
    bucket         = "terraform-remote-backend-199944304157"
    dynamodb_table = "terraform-remote-backend-199944304157"
    key            = "global/route53/terraform.tfstate"
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