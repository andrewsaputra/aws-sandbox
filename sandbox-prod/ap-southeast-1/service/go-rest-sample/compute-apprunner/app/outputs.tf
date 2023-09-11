output "apprunner_arn" {
  value = aws_apprunner_service.app.arn
}

output "apprunner_domain_dns_target" {
  value = aws_apprunner_custom_domain_association.app.dns_target
}

output "apprunner_domain_certificate_validation_records" {
  value = aws_apprunner_custom_domain_association.app.certificate_validation_records
}