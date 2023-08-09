data "aws_iam_policy_document" "cicd" {
  statement {
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }

    actions = [
      "kms:*"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.cicd_kms_users
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = ["*"]
  }
}


resource "aws_kms_key" "cicd" {
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 7
  policy                   = data.aws_iam_policy_document.cicd.json
}

resource "aws_kms_alias" "cicd" {
  name          = "alias/ci-cd"
  target_key_id = aws_kms_key.cicd.key_id
}

