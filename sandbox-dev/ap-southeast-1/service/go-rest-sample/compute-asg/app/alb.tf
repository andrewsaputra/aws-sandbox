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

resource "aws_lb_target_group" "app" {
  name                 = "${local.identifier}-tg"
  port                 = local.app.port
  protocol             = local.target_group.protocol
  deregistration_delay = local.target_group.deregistration_delay
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

#resource "aws_lb_target_group_attachment" "app" {
#  target_group_arn = aws_lb_target_group.app.arn
#  target_id        = aws_instance.app.id
#}


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
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
