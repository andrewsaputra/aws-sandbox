######################
### SECURITY GROUP ###

resource "aws_security_group" "alb" {
  name   = "${local.identifier}-alb"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.identifier}-alb"
  }
}

resource "aws_security_group_rule" "alb_ingress_1" {
  type              = "ingress"
  from_port         = local.alb.port
  to_port           = local.alb.port
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress_1" {
  type                     = "egress"
  from_port                = local.app.port
  to_port                  = local.app.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.app.id
}


####################
### TARGET GROUP ###

resource "aws_lb_target_group" "blue" {
  name                 = "${local.identifier}-blue-tg"
  port                 = local.app.port
  protocol             = local.target_group.protocol
  deregistration_delay = local.target_group.deregistration_delay
  target_type          = local.target_group.target_type
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id

  health_check {
    healthy_threshold   = local.target_group.health_check.num_consecutive
    unhealthy_threshold = local.target_group.health_check.num_consecutive
    interval            = local.target_group.health_check.interval
    timeout             = local.target_group.health_check.timeout
    path                = local.target_group.health_check.path
    protocol            = local.target_group.health_check.protocol
    port                = local.target_group.health_check.port
    matcher             = local.target_group.health_check.matcher
  }
}

resource "aws_lb_target_group" "green" {
  name                 = "${local.identifier}-green-tg"
  port                 = local.app.port
  protocol             = local.target_group.protocol
  deregistration_delay = local.target_group.deregistration_delay
  target_type          = local.target_group.target_type
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id

  health_check {
    healthy_threshold   = local.target_group.health_check.num_consecutive
    unhealthy_threshold = local.target_group.health_check.num_consecutive
    interval            = local.target_group.health_check.interval
    timeout             = local.target_group.health_check.timeout
    path                = local.target_group.health_check.path
    protocol            = local.target_group.health_check.protocol
    port                = local.target_group.health_check.port
    matcher             = local.target_group.health_check.matcher
  }
}


#####################
### LOAD BALANCER ###

resource "aws_lb" "app" {
  name               = "${local.identifier}-lbext"
  internal           = local.alb.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnets


  access_logs {
    bucket  = data.terraform_remote_state.global_s3.outputs.lb_logs_bucket
    enabled = true
  }

  tags = {
    Name = "${local.identifier}-lbext"
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = local.alb.port
  protocol          = local.alb.protocol
  ssl_policy        = local.alb.ssl_policy
  certificate_arn   = data.terraform_remote_state.global_route53.outputs.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}


################
### ROUTE 53 ###

resource "aws_route53_record" "main" {
  zone_id = data.terraform_remote_state.global_route53.outputs.zone_id
  name    = local.identifier
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}
