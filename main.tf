terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.4.0"
    }
  }
  backend "s3" {
    bucket                  = "terraform-preview-tahara"
    key                     = "state"
    region                  = "me-central-1"
    # shared_credentials_file = "~/.aws/credentials"
  }
}


#provider "aws" {
#  # Configuration options
#  region  = "me-central-1"
#  profile = "default"
#  #  access_key = "my-access-key"
#  #  secret_key = "my-secret-key"
#}
##########################################################

data "aws_vpcs" "vpcs" {
  tags = {
    name = "tahara"
  }
}

output "vpcs" {
  value = data.aws_vpcs.vpcs.ids
}


data "aws_subnets" "subs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.vpcs.ids[0]]
  }
  tags = {
    Type = "Public"
  }
}
output "subs" {
  value = data.aws_subnets.subs.ids
}
data "aws_subnets" "priv-subs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.vpcs.ids[0]]
  }
  tags = {
    Type = "Private"
  }
}
output "priv-subs" {
  value = data.aws_subnets.priv-subs.ids
}

################################ Creating ALP #########################################
## Creating the ELP Sec group
resource "aws_security_group" "allow_tls" {
  name        = "Preview LP sec grp"
  description = "Allow Http/s inbound traffic"
  vpc_id      = data.aws_vpcs.vpcs.ids[0]

  ingress {
    description      = "Https from Outside world"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Https from Outside world"
    from_port        = 8443
    to_port          = 8443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Http from Outside world"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Http from Outside world"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "secgrp-ALP-preview"
    Env  = "Preview"
  }
}

data "aws_security_groups" "lb_sg" {
  tags = {
    Env  = "Preview"
    Name = "secgrp-ALP-preview"
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.vpcs.ids[0]]
  }
  depends_on = [aws_security_group.allow_tls]

}
output "lb_sg" {
  value = data.aws_security_groups.lb_sg
}

#output "subs_" {
#  value = [ for subnet in data.aws_subnets.subs.ids : subnet]
#}

resource "aws_lb" "alp" {
  name               = "preview-lp"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_groups.lb_sg.ids[0]]
  subnets            = [for subnet_id in data.aws_subnets.subs.ids : subnet_id]

  enable_deletion_protection = false


  tags = {
    Environment = "preview"
    Env         = "preview"
  }
  depends_on = [aws_security_group.allow_tls]
}
#######################################################################################

data "aws_ecs_cluster" "ecs-cluster" {
  cluster_name = "ProdCluster"
}

output "ecscl" {
  value = data.aws_ecs_cluster.ecs-cluster.id
}
################ Creating EFS systems and their required Security Groups ######################
#### Creating sec group for task #########
resource "aws_security_group" "secgrp-frontend-preview" {
  name        = "secgrp-frontend-preview"
  description = "sec group used by frontend in preview env"
  vpc_id      = data.aws_vpcs.vpcs.ids[0]

  ingress {
    description     = "Allow ALP to access frontend"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [data.aws_security_groups.lb_sg.ids[0]]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Env  = "preview"
    Name = "secgrp-frontend-preview"
  }
}

data "aws_security_groups" "secgrp-frontend-preview" {
  tags = {
    Name = "secgrp-frontend-preview"
  }
  depends_on = [aws_security_group.secgrp-frontend-preview]
}

output "sg-frontend" {
  value      = data.aws_security_groups.secgrp-frontend-preview
  depends_on = [data.aws_security_groups.secgrp-frontend-preview]
}
###################################################
resource "aws_security_group" "secgrp-backend-preview" {
  name        = "secgrp-backend-preview"
  description = "sec group used by backend in preview env"
  vpc_id      = data.aws_vpcs.vpcs.ids[0]

  ingress {
    description     = "Allow frontend & loadbalancer to access backend"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [data.aws_security_groups.secgrp-frontend-preview.ids[0], data.aws_security_groups.lb_sg.ids[0]]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Environment = "preview"
    Env         = "preview"
    Name        = "secgrp-backend-preview"
  }
  depends_on = [aws_security_group.secgrp-frontend-preview]
}

data "aws_security_groups" "secgrp-backend-preview" {
  tags = {
    Name = "secgrp-backend-preview"
  }
  depends_on = [aws_security_group.secgrp-backend-preview]
}

output "sg-backend" {
  value = data.aws_security_groups.secgrp-backend-preview
}

############################################################################
# editting testing RDS sec group to allow preview backend to connect to
data "aws_security_group" "secgrp-RDS-testing" {
  id = "sg-0b7f30c646fa09ab3"
}

resource "aws_security_group_rule" "rds-sec-rule" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.secgrp-RDS-testing.id
  source_security_group_id = data.aws_security_groups.secgrp-backend-preview.ids[0]
  depends_on               = [data.aws_security_group.secgrp-RDS-testing, data.aws_security_groups.secgrp-backend-preview]
  description              = "Allowing preview backend to use testing RDS"
}
############################################################################
# editting testing Redis sec group to allow preview backend to connect to
data "aws_security_group" "secgrp-REDIS-testing" {
  id = "sg-0c2f4ed74feba0757"
}

resource "aws_security_group_rule" "redis-sec-rule" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.secgrp-REDIS-testing.id
  source_security_group_id = data.aws_security_groups.secgrp-backend-preview.ids[0]
  depends_on               = [data.aws_security_group.secgrp-REDIS-testing, data.aws_security_groups.secgrp-backend-preview]
  description              = "Allow preview backend to use testing REDIS"
}
############################################################################


module "efs" {
  source       = "git::https://github.com/terraform-iaac/terraform-aws-efs?ref=v2.0.4"
  name         = "preview-uploads"
  vpc_id       = data.aws_vpcs.vpcs.ids[0]
  subnet_ids   = [for subnet_id in data.aws_subnets.subs.ids : subnet_id]
  whitelist_sg = ["sg-07e7efdd88a429620", data.aws_security_groups.secgrp-backend-preview.ids[0]]
  depends_on   = [aws_security_group.allow_tls, aws_security_group.secgrp-frontend-preview, aws_security_group.secgrp-backend-preview]
  tags = {
    Environment = "preview"
    Name        = "preview-uploads"
  }
}

module "efs-1" {
  source       = "./.terraform/modules/efs"
  name         = "preview-apache"
  vpc_id       = data.aws_vpcs.vpcs.ids[0]
  subnet_ids   = [for subnet_id in data.aws_subnets.subs.ids : subnet_id]
  whitelist_sg = ["sg-07e7efdd88a429620", data.aws_security_groups.secgrp-backend-preview.ids[0]]
  depends_on   = [aws_security_group.allow_tls, aws_security_group.secgrp-frontend-preview, aws_security_group.secgrp-backend-preview]
  tags = {
    Environment = "preview"
    Name        = "preview-apache"
  }
}


data "aws_efs_file_system" "volume-uploads" {
  tags = {
    Environment = "preview"
    Name        = "preview-uploads"
  }
  depends_on = [module.efs]
}

data "aws_efs_file_system" "volume-apache" {
  tags = {
    Environment = "preview"
    Name        = "preview-apache"
  }
  depends_on = [module.efs-1]
}

output "vol-apache" {
  value = data.aws_efs_file_system.volume-apache.file_system_id
}


################################################################################################
################ Creating task def #########################

data "aws_iam_role" "execution-role" {
  name = "ecsTaskExecutionRole"
}
resource "aws_ecs_task_definition" "backend" {
  family                = "preview-backend"
  container_definitions = file("task-definitions/container-df-backend.json")
  cpu                   = 512
  memory                = 1024
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  volume {
    name = "uploads"
    efs_volume_configuration {
      file_system_id = data.aws_efs_file_system.volume-uploads.file_system_id
      root_directory = "/"
    }
  }
  volume {
    name = "apache"
    efs_volume_configuration {
      file_system_id = data.aws_efs_file_system.volume-apache.file_system_id
      root_directory = "/"
    }
  }
  task_role_arn      = aws_iam_role.ecs-exec-preview-task-role.arn
  execution_role_arn = data.aws_iam_role.execution-role.arn
  tags = {
    Env     = "preview"
    Service = "backend"
  }
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  depends_on               = [module.efs, module.efs-1, aws_iam_policy.preview-uploads-pol, aws_iam_policy.preview-apache-pol, aws_iam_role.ecs-exec-preview-task-role, data.aws_iam_role.execution-role]

}

data "aws_ecs_task_definition" "preview-backend" {
  task_definition = "preview-backend"
  depends_on = [aws_ecs_task_definition.backend]
}

output "task-def-backend" {
  value = data.aws_ecs_task_definition.preview-backend
}

##################################################################################################