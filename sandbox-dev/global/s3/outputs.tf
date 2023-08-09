output "codepipeline_artifacts_bucket" {
    value = aws_s3_bucket.codepipeline.bucket
}

output "codepipeline_artifacts_arn" {
    value = aws_s3_bucket.codepipeline.arn
}

output "lb_logs_bucket" {
    value = aws_s3_bucket.lb_logs.bucket
}

output "lb_logs_arn" {
    value = aws_s3_bucket.lb_logs.arn
}