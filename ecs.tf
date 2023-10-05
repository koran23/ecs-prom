resource "aws_security_group" "service" {
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_http.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "app_log_group" {
  name = "/ecs/${var.app_name}-task"
}

resource "aws_ecs_cluster" "cluster" {
  name = var.app_name
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 2048
  cpu                      = 1024
  task_role_arn          = aws_iam_role.ecsTaskRole.arn
  execution_role_arn     = aws_iam_role.ecsTaskExecutionRole.arn

  container_definitions = jsonencode([
  {
    name      = "${var.app_name}-task",
    image     = aws_ecr_repository.app.repository_url,
    essential = true,
    portMappings = [
      {
        containerPort = 3000
      }
    ],
    memory = 1536,
    cpu    = 768,
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-region" = "${var.region}", 
        "awslogs-group"  = "/ecs/${var.app_name}-task", 
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }
])
}

resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  enable_execute_command = true


  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.app_name}-task"
    container_port   = 3000
  }

  network_configuration {
    subnets          = [aws_default_subnet.default_subnet_a.id, aws_default_subnet.default_subnet_b.id, aws_default_subnet.default_subnet_c.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.service.id]
  }

  depends_on = [
    aws_alb.alb,
    aws_lb_target_group.app,
  ]
}
