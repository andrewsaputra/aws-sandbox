output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "zone_name_servers" {
  value = aws_route53_zone.main.name_servers
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.main.arn
}

output "acm_certificate_domain_name" {
  value = aws_acm_certificate.main.domain_name
}
