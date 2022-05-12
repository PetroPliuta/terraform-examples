resource "aws_lb" "my-alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb-sg]

#   subnets            = [for subnet in aws_subnet.public : subnet.id]
  subnets = var.subnets
#   subnets = [for subnet in var.subnets : subnet]

#   enable_deletion_protection = true

}

data "aws_instances" "my-instances"{
    instance_tags = {
        ec2-id = var.ec2-id-tag
    }
    # instance_state_names = ["running"]
}

resource "aws_lb_target_group" "my-tg"{
  name        = "my-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc-id

  health_check {
      path = "/"
      port = 80
      protocol = "HTTP"
  }
}

resource "aws_lb_target_group_attachment" "my-attachment" {
#   count = length(data.aws_instances.my-instances.ids)
  count = var.instances-count

  
  target_group_arn = aws_lb_target_group.my-tg.arn
  target_id        = data.aws_instances.my-instances.ids[count.index]
#   port             = 80
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.my-alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-tg.arn
  }
}
