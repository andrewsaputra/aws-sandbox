locals {

  identifier = "go-rest-sample"
  
  cross_account_arns = [
    "arn:aws:iam::958954650561:root",
  ]

}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_ecr_repository" "app" {
  name                 = local.identifier
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = <<EOF
{
  "rules": [
      {
          "rulePriority": 1,
          "description": "expire images older than 3 days",
          "selection": {
              "tagStatus": "tagged",
              "tagPrefixList": ["rev_"],
              "countType": "sinceImagePushed",
              "countUnit": "days",
              "countNumber": 3
          },
          "action": {
              "type": "expire"
          }
      }
  ]
}
EOF
}

resource "aws_ecr_repository_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy     = data.aws_iam_policy_document.app.json
}


data "aws_iam_policy_document" "app" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = local.cross_account_arns
    }

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
  }
}