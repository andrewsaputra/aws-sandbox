output "app_cluster_name" {
  value = aws_ecs_cluster.app.name
}

output "app_service_name" {
  value = aws_ecs_service.app.name
}

output "alb_listener" {
  value = aws_lb_listener.app.arn
}

output "blue_target_group_name" {
  value = aws_lb_target_group.blue.name
}

output "green_target_group_name" {
  value = aws_lb_target_group.green.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}