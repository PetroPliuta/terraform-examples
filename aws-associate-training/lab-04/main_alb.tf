# Application load balancer

resource "aws_security_group" "alb" {
  name        = "alb"
  description = "allows access to alb"
  vpc_id      = aws_vpc.cloudx.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # security_groups = [aws_security_group.ec2_pool.id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    # Necessary if changing 'name' or 'name_prefix' properties.
    create_before_destroy = true
  }
  tags = {
    "Name" = "alb"
  }
}

resource "aws_lb" "ghost-app" {
  name               = "ghost-app"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id, aws_subnet.public_c.id]
}

resource "aws_lb_target_group" "ghost-ec2" {
  name_prefix = "ec2"
  port        = 2368
  protocol    = "HTTP"
  vpc_id      = aws_vpc.cloudx.id

  slow_start = 300
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 6
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    "Name" = "ghost-ec2"
  }
}
resource "aws_lb_target_group" "ghost-fargate" {
  name_prefix = "fargat"
  port        = 2368
  protocol    = "HTTP"
  vpc_id      = aws_vpc.cloudx.id

  target_type = "ip"
  # slow_start = 600

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 6
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    "Name" = "ghost-fargate"
  }
}

resource "aws_lb_listener" "ghost-ec2" {
  load_balancer_arn = aws_lb.ghost-app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.ghost-ec2.arn
        weight = 50
      }
      target_group {
        arn    = aws_lb_target_group.ghost-fargate.arn
        weight = 50
      }
    }
  }
}
