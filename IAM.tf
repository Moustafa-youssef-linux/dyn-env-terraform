

################# Creating IAM polices & Roles for task ########################################
#!- uploads policy
#2- apache policy
#3- preview task policy
#4- preview task role


resource "aws_iam_policy" "preview-uploads-pol" {
  name        = "preview-uploads"
  path        = "/"
  description = "policy to let task access uploads volume in preview env"
  tags = {
    Env = "preview"
  }

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    "Statement": [
      {
        "Sid": "VisualEditor0",
        "Effect": "Allow",
        "Action": [
          "elasticfilesystem:PutAccountPreferences",
          "elasticfilesystem:CreateFileSystem",
          "elasticfilesystem:DescribeAccountPreferences"
        ],
        "Resource": "*"
      },
      {
        "Sid": "VisualEditor1",
        "Effect": "Allow",
        "Action": "elasticfilesystem:*",
        "Resource": data.aws_efs_file_system.volume-uploads.arn
      }
    ]
  })
}

resource "aws_iam_policy" "preview-apache-pol" {
  name        = "preview-apache"
  path        = "/"
  description = "policy to let task access apache volume in preview env"
  tags = {
    Env = "preview"
  }

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    "Statement": [
      {
        "Sid": "VisualEditor0",
        "Effect": "Allow",
        "Action": [
          "elasticfilesystem:PutAccountPreferences",
          "elasticfilesystem:CreateFileSystem",
          "elasticfilesystem:DescribeAccountPreferences"
        ],
        "Resource": "*"
      },
      {
        "Sid": "VisualEditor1",
        "Effect": "Allow",
        "Action": "elasticfilesystem:*",
        "Resource": data.aws_efs_file_system.volume-apache.arn
      }
    ]
  })
}


resource "aws_iam_policy" "ecs-exec-preview-task-role-policy" {
  name        = "ecs-exec-preview-task-role-policy"
  path        = "/"
  description = "policy to let task access log group and s3"
  tags = {
    Env = "preview"
  }

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:DescribeLogGroups"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:me-central-1:996404169526:log-group:/aws/ecs/ecs-exec-demo:*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject"
        ],
        "Resource": "arn:aws:s3:::ecs-exec-output-3637495736/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetEncryptionConfiguration"
        ],
        "Resource": "arn:aws:s3:::ecs-exec-output-3637495736"
      }
    ]
  })
}


################################################################################################
######################################### TASK ROLE ############################################

resource "aws_iam_role" "ecs-exec-preview-task-role" {
  name = "ecs-exec-preview-task-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = [aws_iam_policy.preview-uploads-pol.arn, aws_iam_policy.preview-apache-pol.arn, aws_iam_policy.ecs-exec-preview-task-role-policy.arn]

  tags = {
    Env = "preview"
    Environment = "preview"
  }
  depends_on = [aws_iam_policy.preview-apache-pol, aws_iam_policy.preview-uploads-pol, aws_iam_policy.ecs-exec-preview-task-role-policy]
}
################################################################################################