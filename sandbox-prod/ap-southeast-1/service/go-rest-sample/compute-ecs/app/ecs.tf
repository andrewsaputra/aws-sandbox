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

resource "aws_security_group_rule" "app_ingress_1" {
  type                     = "ingress"
  from_port                = local.app.port
  to_port                  = local.app.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
}


######################
### ECS LOG GROUPS ###

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "${local.identifier}-ecs-exec"
  retention_in_days = 3

  tags = {
    Name = "${local.identifier}-ecs-exec"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "${local.identifier}-app"
  retention_in_days = 3

  tags = {
    Name = "${local.identifier}-app"
  }
}


###########
### ECS ###

resource "aws_ecs_cluster" "app" {
  name = "cluster-${local.identifier}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

}

resource "aws_ecs_cluster_capacity_providers" "app" {
  cluster_name       = aws_ecs_cluster.app.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 0
    weight            = 100
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "task-${local.identifier}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.app.cpu_units
  memory                   = local.app.memory_units
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = templatefile("task-definition.json", {
    cpu_units : local.app.cpu_units
    memory_units : local.app.memory_units
    app_port : local.app.port
    ecr_image : "${local.ecr_repository_url}:latest"
    log_group_name : aws_cloudwatch_log_group.app.name
    log_group_region : data.aws_region.current.id
    log_stream_prefix : "task"
  })
}

resource "aws_ecs_service" "app" {
  name                               = "${local.identifier}-app"
  cluster                            = aws_ecs_cluster.app.id
  desired_count                      = 0
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 80
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  task_definition                    = aws_ecs_task_definition.app.arn
  enable_execute_command             = true
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"

  network_configuration {
    subnets          = data.terraform_remote_state.vpc.outputs.app_subnets
    assign_public_ip = false
    security_groups = [
      aws_security_group.app.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "app"
    container_port   = local.app.port
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  tags = {
    Name = "${local.identifier}-app"
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }
}


########################
### ECS AUTO SCALING ###

resource "aws_appautoscaling_target" "app" {
  resource_id        = "service/${aws_ecs_cluster.app.name}/${aws_ecs_service.app.name}"
  service_namespace  = "ecs"
  min_capacity       = 1
  max_capacity       = 3
  scalable_dimension = "ecs:service:DesiredCount"
}

resource "aws_appautoscaling_policy" "app" {
  name               = "target-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}