################
### IAM ROLE ###

# https://docs.aws.amazon.com/apprunner/latest/dg/security_iam_service-with-iam.html#security_iam_service-with-iam-roles

resource "aws_iam_role" "access_role" {
  name               = "access-role-${local.identifier}"
  assume_role_policy = data.aws_iam_policy_document.assume_apprunner_access_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess",
  ]
}

data "aws_iam_policy_document" "assume_apprunner_access_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "instance_role" {
  name               = "instance-role-${local.identifier}"
  assume_role_policy = data.aws_iam_policy_document.assume_apprunner_instance_role.json

}

data "aws_iam_policy_document" "assume_apprunner_instance_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["tasks.apprunner.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}