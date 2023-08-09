output "codebuild_role_arn" {
  value = aws_iam_role.codebuild.arn
}

output "codepipeline_role_arn" {
  value = aws_iam_role.codepipeline.arn
}

output "codedeploy_role_arn" {
  value = aws_iam_role.codedeploy.arn
}