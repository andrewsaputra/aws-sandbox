################
### IAM ROLE ###

resource "aws_iam_role" "app" {
  name               = "instance-role-${local.identifier}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
}

resource "aws_iam_instance_profile" "app" {
  name = aws_iam_role.app.name
  role = aws_iam_role.app.name
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


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


#######################
### LAUNCH TEMPLATE ###

resource "aws_launch_template" "app" {
  name                   = "${local.identifier}-app-lt"
  image_id               = local.app_ami_id
  instance_type          = local.app.instance_type
  ebs_optimized          = true
  update_default_version = true
  user_data              = filebase64("ec2-asg-init.sh")

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  credit_specification {
    cpu_credits = "unlimited"
  }
}

resource "random_id" "app_asg" {
  byte_length = 8

  keepers = {
    Target = "asg-app"
  }

  prefix = "${local.identifier}-app-"
}

resource "aws_autoscaling_group" "app" {
  name                      = random_id.app_asg.hex
  min_size                  = local.app.asg.min_size
  desired_capacity          = local.app.asg.desired_size
  max_size                  = local.app.asg.max_size
  default_cooldown          = local.app.asg.default_cooldown
  default_instance_warmup   = local.app.asg.default_instance_warmup
  health_check_grace_period = local.app.asg.health_check_grace_period
  health_check_type         = local.app.asg.health_check_type
  wait_for_capacity_timeout = local.app.asg.wait_for_capacity_timeout
  vpc_zone_identifier       = local.app.asg.subnets
  max_instance_lifetime     = local.app.asg.max_instance_lifetime

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  mixed_instances_policy {
    instances_distribution {
      on_demand_allocation_strategy = "lowest-price"
      spot_max_price                = 0.0041
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.app.id
        version            = "$Latest" #aws_launch_template.app.latest_version
      }

      override {
        instance_type = local.app.instance_type
      }
    }
  }

  instance_refresh {
    strategy = "Rolling"
  }

  tag {
    key                 = "Name"
    value               = random_id.app_asg.hex
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.app.asg.extra_tags

    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = tag.value.propagate_at_launch
    }

  }

  lifecycle {
    create_before_destroy = true

    ignore_changes = [
      desired_capacity
    ]
  }
}