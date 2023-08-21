resource "aws_route53_zone" "main" {
  name = "dev.zenithbytes.xyz"
}

resource "aws_acm_certificate" "main" {
  domain_name       = "*.${aws_route53_zone.main.name}"
  validation_method = "DNS"
  key_algorithm     = "RSA_2048"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cname_validation" {
  count = length(aws_acm_certificate.main.domain_validation_options)

  zone_id = aws_route53_zone.main.zone_id
  name    = tolist(aws_acm_certificate.main.domain_validation_options)[count.index].resource_record_name
  type    = tolist(aws_acm_certificate.main.domain_validation_options)[count.index].resource_record_type
  ttl     = 300
  records = [
    tolist(aws_acm_certificate.main.domain_validation_options)[count.index].resource_record_value
  ]
}
