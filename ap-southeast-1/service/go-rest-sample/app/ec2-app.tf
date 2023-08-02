#######################
### SECURITY GROUPS ###

resource "aws_security_group" "app" {
  name   = "${local.identifier}-app"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.identifier}-app"
  }
}

resource "aws_security_group_rule" "app_ingress_1" {
  type                     = "ingress"
  from_port                = local.app.port
  to_port                  = local.app.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "app_egress_1" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.app.id
  cidr_blocks       = ["0.0.0.0/0"]
}


################
### IAM ROLE ###

resource "aws_iam_role" "app" {
  name               = "instance-role-${local.identifier}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  inline_policy {
    name   = "permissions"
    policy = data.aws_iam_policy_document.app_policy.json
  }
}

resource "aws_iam_instance_profile" "app" {
  name = aws_iam_role.app.name
  role = aws_iam_role.app.name
}

data "aws_iam_policy_document" "app_policy" {
  statement {
    # https://docs.amazonaws.cn/en_us/codedeploy/latest/userguide/getting-started-create-iam-instance-profile.html#getting-started-create-iam-instance-profile-console
    sid    = "ManageCodeDeployAgent"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::aws-codedeploy-${data.aws_region.current.name}/*",
    ]
  }

  statement {
    sid    = "DownloadAppArtifacts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${data.terraform_remote_state.global_s3.outputs.codepipeline_artifacts_arn}/*",
    ]
  }
}


############
### EC2 ####

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = local.app.ami.owners

  filter {
    name   = "name"
    values = [local.app.ami.name]
  }
  filter {
    name   = "architecture"
    values = [local.app.ami.architecture]
  }
  filter {
    name   = "virtualization-type"
    values = [local.app.ami.virtualization]
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = local.app.instance_type
  associate_public_ip_address = local.app.associate_public_ip
  ebs_optimized               = true
  iam_instance_profile        = aws_iam_instance_profile.app.name
  subnet_id                   = data.terraform_remote_state.vpc.outputs.public_subnets[0]
  user_data                   = file("ec2-app-init.sh")

  vpc_security_group_ids = [aws_security_group.app.id]

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = 0.004
    }
  }

  tags = {
    Name = "${local.identifier}-app"
  }
}