output "repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "auth_endpoint" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com"
}