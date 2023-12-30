################################ Creating ECS Service #################################

# 1- Creating ECS service

############ Getting service details #################
resource "aws_ecs_service" "preview-backend" {
  name            = "preview-backend"
  cluster         = data.aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  platform_version= "LATEST"
  tags = {
     Env = "preview"
  }
  depends_on = [aws_ecs_task_definition.backend,aws_lb_target_group.preview-backend]


  load_balancer {
    target_group_arn = aws_lb_target_group.preview-backend.arn
    container_name   = "backend"
    container_port   = 443
  }
  network_configuration {
    subnets = [for subnet_id in data.aws_subnets.priv-subs.ids : subnet_id]
    assign_public_ip = false
    security_groups = [data.aws_security_groups.secgrp-backend-preview.ids[0]]
  }

}

######################################################