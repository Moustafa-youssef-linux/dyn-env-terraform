################ Creating Front-End task def #########################

resource "aws_ecs_task_definition" "frontend" {
  family                = "preview-frontend"
  container_definitions = file("task-definitions/container-df-frontend.json")
  cpu                   = 512
  memory                = 1024
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  #task_role_arn      = aws_iam_role.ecs-exec-preview-task-role.arn  No need for task Role
  execution_role_arn = data.aws_iam_role.execution-role.arn
  tags = {
    Env     = "preview"
    Service = "frontend"
  }
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  depends_on               = [aws_ecs_service.preview-backend,aws_lb.alp,aws_lb_target_group.preview-frontend]

}

data "aws_ecs_task_definition" "preview-frontend" {
  task_definition = "preview-frontend"
  depends_on = [aws_ecs_task_definition.frontend]
}

output "task-def-frontend" {
  value = data.aws_ecs_task_definition.preview-frontend
}

##################################################################################################
################################ Creating ECS Front-end Service ##################################

# 1- Creating ECS service

############ Getting service details #################
resource "aws_ecs_service" "preview-frontend" {
  name            = "preview-frontend"
  cluster         = data.aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  platform_version= "LATEST"
  tags = {
    Env = "preview"
    service = "frontend"
  }
  depends_on = [aws_ecs_task_definition.backend,aws_lb_target_group.preview-frontend,aws_lb.alp]


  load_balancer {
    target_group_arn = aws_lb_target_group.preview-frontend.arn
    container_name   = "frontend"
    container_port   = 3000
  }
  network_configuration {
    subnets = [for subnet_id in data.aws_subnets.priv-subs.ids : subnet_id]
    assign_public_ip = false
    security_groups = [data.aws_security_groups.secgrp-frontend-preview.ids[0]]
  }

}

##################################################################################################