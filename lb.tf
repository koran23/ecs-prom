resource "aws_security_group" "alb_http" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "alb" {
  name               = "alb"
  load_balancer_type = "application"
  subnets            = [aws_default_subnet.default_subnet_a.id, aws_default_subnet.default_subnet_b.id, aws_default_subnet.default_subnet_c.id]
  security_groups    = [aws_security_group.alb_http.id]
}

resource "aws_lb_target_group" "app" {
  name        = "app-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id

  health_check {
    matcher = "200,301,302"
    path    = "/"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener_rule" "default" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
