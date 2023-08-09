output "lb_logs_bucket" {
  value = aws_s3_bucket.lb_logs.bucket
}

output "lb_logs_arn" {
  value = aws_s3_bucket.lb_logs.arn
}