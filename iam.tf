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

resource "aws_iam_role_policy_attachment" "ecs_execute_command_attachment" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = aws_iam_policy.ecs_execute_command.arn
}


resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role" "ecsTaskRole" {
  name               = "ecsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
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
