locals {

  identifier     = "go-rest-sample"
  route53_domain = "dev.zenithbytes.xyz"

  remote_state_backend            = "s3"
  remote_state_bucket             = "terraform-remote-backend-199944304157"
  remote_state_region             = "ap-southeast-1"
  remote_state_key_global_route53 = "global/route53/terraform.tfstate"
  remote_state_key_app            = "ap-southeast-1/service/go-rest-sample/compute-apprunner/app/terraform.tfstate"
}

data "terraform_remote_state" "global_route53" {
  backend = local.remote_state_backend

  config = {
    bucket = local.remote_state_bucket
    key    = local.remote_state_key_global_route53
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


resource "aws_route53_record" "app" {
  zone_id = data.terraform_remote_state.global_route53.outputs.zone_id
  name    = "${local.identifier}.${local.route53_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [
    data.terraform_remote_state.app.outputs.apprunner_domain_dns_target
  ]
}

resource "aws_route53_record" "validation" {
  count = length(data.terraform_remote_state.app.outputs.apprunner_domain_certificate_validation_records)

  zone_id = data.terraform_remote_state.global_route53.outputs.zone_id
  name    = tolist(data.terraform_remote_state.app.outputs.apprunner_domain_certificate_validation_records)[count.index].name
  type    = tolist(data.terraform_remote_state.app.outputs.apprunner_domain_certificate_validation_records)[count.index].type
  ttl     = 300
  records = [
    tolist(data.terraform_remote_state.app.outputs.apprunner_domain_certificate_validation_records)[count.index].value
  ]
}