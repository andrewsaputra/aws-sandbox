##############################
### CODEPIPELINE ARTIFACTS ###

resource "random_id" "codepipeline" {
  byte_length = 8

  keepers = {
    Target = "codepipeline-artifacts"
  }

  prefix = "codepipeline-artifacts-"
}

resource "aws_s3_bucket" "codepipeline" {
  bucket = random_id.codepipeline.hex
}

resource "aws_s3_bucket_lifecycle_configuration" "codepipeline" {
  bucket = aws_s3_bucket.codepipeline.id

  rule {
    id     = "expiration-rule"
    status = "Enabled"

    filter {
    }

    expiration {
      days = 3
    }
  }
}

##########################
### LOAD BALANCER LOGS ###

resource "random_id" "lb_logs" {
  byte_length = 8

  keepers = {
    Target = "lb-logs"
  }

  prefix = "lb-logs-"
}

resource "aws_s3_bucket" "lb_logs" {
  bucket = random_id.lb_logs.hex
}

resource "aws_s3_bucket_lifecycle_configuration" "lb_logs" {
  bucket = aws_s3_bucket.lb_logs.id

  rule {
    id     = "expiration-rule"
    status = "Enabled"

    filter {
    }

    expiration {
      days = 3
    }
  }
}

# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
data "aws_iam_policy_document" "lb_logs_policy" {

  statement {
    sid    = "AllowRegionsAfterAugust2022"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "logdelivery.elasticloadbalancing.amazonaws.com"
      ]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.lb_logs.arn}/*",
    ]

  }
  statement {
    sid    = "AllowRegionsBeforeAugust2022"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::114774131450:root", # ap-southeast-1
      ]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.lb_logs.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "lb_logs_allow_logging" {
  bucket = aws_s3_bucket.lb_logs.id
  policy = data.aws_iam_policy_document.lb_logs_policy.json
}

