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

resource "aws_security_group_rule" "app_egress_1" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.app.id
  cidr_blocks       = ["0.0.0.0/0"]
}


##################
### APP RUNNER ###

resource "aws_apprunner_vpc_connector" "app" {
  vpc_connector_name = "connector-${local.identifier}"
  subnets            = data.terraform_remote_state.vpc.outputs.app_subnets
  security_groups    = [aws_security_group.app.id]
}

resource "aws_apprunner_auto_scaling_configuration_version" "app" {
  auto_scaling_configuration_name = "scaling-${local.identifier}"

  max_concurrency = local.app.scaling_policy.max_concurrency
  max_size        = local.app.scaling_policy.max_size
  min_size        = local.app.scaling_policy.min_size

  tags = {
    Name = "scaling-${local.identifier}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apprunner_service" "app" {
  service_name                   = "runner-${local.identifier}"
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.app.arn

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.access_role.arn
    }

    image_repository {
      image_configuration {
        port = local.app.port
      }

      image_identifier      = "${local.ecr_repository_url}:latest"
      image_repository_type = "ECR"
    }

    auto_deployments_enabled = false
  }

  network_configuration {
    ingress_configuration {
      is_publicly_accessible = true
    }

    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.app.arn
    }
  }

  health_check_configuration {
    protocol            = local.app.health_check.protocol
    path                = local.app.health_check.path
    interval            = local.app.health_check.interval
    timeout             = local.app.health_check.timeout
    healthy_threshold   = local.app.health_check.num_consecutive
    unhealthy_threshold = local.app.health_check.num_consecutive
  }

  instance_configuration {
    cpu               = local.app.cpu_units
    memory            = local.app.memory_units
    instance_role_arn = aws_iam_role.instance_role.arn
  }

  tags = {
    Name = "runner-${local.identifier}"
  }
}


#####################
### CUSTOM DOMAIN ###

resource "aws_apprunner_custom_domain_association" "app" {
  domain_name          = "${local.identifier}.${local.route53_domain}"
  service_arn          = aws_apprunner_service.app.arn
  enable_www_subdomain = false
}
