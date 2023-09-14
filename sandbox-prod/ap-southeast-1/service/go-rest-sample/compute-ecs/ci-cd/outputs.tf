output "codedeploy_app_name" {
  value = aws_codedeploy_deployment_group.release.app_name
}

output "codedeploy_group_name" {
  value = aws_codedeploy_deployment_group.release.deployment_group_name
}

output "codedeploy_cross_account_role_arn" {
  value = data.terraform_remote_state.global_cicd.outputs.codedeploy_cross_account_role_arn
}
