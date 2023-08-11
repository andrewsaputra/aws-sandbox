output "cd_app_name" {
  value = aws_codedeploy_deployment_group.release.app_name
}

output "cd_group_name" {
  value = aws_codedeploy_deployment_group.release.deployment_group_name
}