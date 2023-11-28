data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ecs_cloudwatch_logs" {
  name        = "ECSCloudWatchLogs"
  description = "Allow ECS tasks to create and write to CloudWatch logs."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_execute_command" {
  name        = "ECSExecuteCommand"
  description = "Allow ECS tasks to use the execute command feature."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ssm:StartSession",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "ec2_role" {
  name = "EC2MonitoringRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "SecretsManagerPolicy"
  description = "Policy to allow access to Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "secretsmanager:GetSecretValue",
        Effect   = "Allow",
        Resource = "arn:aws:secretsmanager:us-east-1:369383612283:secret:grafana-*"
      }
    ]
  })
}

resource "aws_iam_policy" "thanos_s3_policy" {
  name        = "ThanosS3Policy"
  description = "S3 permissions for Thanos"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = [
          "${aws_s3_bucket.thanos_bucket.arn}",
          "${aws_s3_bucket.thanos_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_service_discovery" {
  name        = "ECSServiceDiscoveryPolicy"
  description = "Policy to allow listing and describing ECS tasks and services."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:ListServices",  # Added this line
          "ecs:DescribeServices"  # Added permission to describe ECS services
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "elb_access_policy" {
  name        = "ELBAccessPolicy"
  description = "Policy to allow access to ELB target groups and load balancers."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeLoadBalancers"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_policy" {
  name        = "ECRAccessPolicy"
  description = "Policy to allow access to ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "elb_access_policy_attach" {
  policy_arn = aws_iam_policy.elb_access_policy.arn
  role       = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attach" {
  policy_arn = aws_iam_policy.ecr_policy.arn
  role       = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_service_discovery_attach" {
  policy_arn = aws_iam_policy.ecs_service_discovery.arn
  role       = aws_iam_role.ec2_role.name
}


resource "aws_iam_role_policy_attachment" "thanos_s3_attach" {
  policy_arn = aws_iam_policy.thanos_s3_policy.arn
  role       = aws_iam_role.ec2_role.name
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role" "ecsTaskRole" {
  name               = "ecsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_secrets_manager_policy" {
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
  role       = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_execute_command_attachment" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = aws_iam_policy.ecs_execute_command.arn
}

resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_logs_attachment" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = aws_iam_policy.ecs_cloudwatch_logs.arn
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecsTaskRole_cloudwatch_logs_attachment" {
  role       = aws_iam_role.ecsTaskRole.name
  policy_arn = aws_iam_policy.ecs_cloudwatch_logs.arn
}
