output "codedeploy_role_arn" {
  value = aws_iam_role.codedeploy.arn
}

output "codedeploy_cross_account_role_arn" {
  value = aws_iam_role.codedeploy_cross_account.arn
}