resource "aws_security_group" "ec2_pool" {
  name        = "ec2_pool"
  description = "allows access to ec2 instances"
  vpc_id      = aws_vpc.cloudx.id

  lifecycle {
    # Necessary if changing 'name' or 'name_prefix' properties.
    create_before_destroy = true
  }
  tags = {
    "Name" = "ec2_pool"
  }
}
resource "aws_security_group_rule" "rule_1" {
  security_group_id        = aws_security_group.ec2_pool.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
}
resource "aws_security_group_rule" "rule_2" {
  security_group_id = aws_security_group.ec2_pool.id
  type              = "ingress"
  from_port         = 2368
  to_port           = 2368
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.cloudx.cidr_block]
}
resource "aws_security_group_rule" "rule_3" {
  security_group_id        = aws_security_group.ec2_pool.id
  type                     = "ingress"
  from_port                = 2368
  to_port                  = 2368
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}
resource "aws_security_group_rule" "rule_1e" {
  security_group_id = aws_security_group.ec2_pool.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# SSH Key pair

resource "aws_key_pair" "ghost-ec2-pool" {
  public_key = var.ssh-key
  key_name   = "ghost-ec2-pool"
  tags = {
    Name = "ghost-ec2-pool"
  }
}


# IAM

resource "aws_iam_policy" "ghost_app" {
  name = "ghost_app"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "ssm:GetParameter*",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
          "rds:DescribeDBInstances",
          "elasticloadbalancing:DescribeLoadBalancers",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = {
    Name = "ghost_app"
  }
}

resource "aws_iam_role" "ghost_app" {
  name = "ghost_app"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [aws_iam_policy.ghost_app.arn]

  tags = {
    Name = "ghost_app"
  }
}

resource "aws_iam_instance_profile" "ghost_app" {
  name = "ghost_app"
  role = aws_iam_role.ghost_app.name
  tags = {
    Name = "ghost_app"
  }
}

# Launch Template

data "aws_ami" "amazon2-linux-latest" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# data "local_file" "ghost-init-script" {
#   filename = "${path.module}/files/ghost-init-script.sh"
# }

data "template_file" "ghost-init-script" {
  template = file("${path.module}/files/ghost-init-script.sh")

  vars = {
    EFS_ID      = aws_efs_file_system.ghost_content.id
    LB_DNS_NAME = aws_lb.ghost-app.dns_name
    DB_URL      = aws_db_instance.ghost.address
    DB_NAME     = aws_db_instance.ghost.db_name
    DB_USER     = aws_db_instance.ghost.username
    DB_PASSWORD = aws_ssm_parameter.db_password.value
  }
}

resource "aws_launch_template" "ghost" {
  name = "ghost"
  iam_instance_profile {
    arn = aws_iam_instance_profile.ghost_app.arn
  }
  image_id      = data.aws_ami.amazon2-linux-latest.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ghost-ec2-pool.key_name
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.ec2_pool.id]
  }

  # user_data = data.local_file.ghost-init-script.content_base64
  user_data = base64encode(data.template_file.ghost-init-script.rendered)

  tag_specifications {
    resource_type = "instance"
    tags = {
      "Name" = "ghost-ec2"
    }
  }
}


# Auto-scaling group

# https://docs.aws.amazon.com/efs/latest/ug/troubleshooting-efs-mounting.html#mount-fails-propegation
# Q: File System Mount Fails Immediately After File System Creation
# A: It can take up to 90 seconds after creating a mount target for 
# the Domain Name Service (DNS) records to propagate fully in an AWS Region.

# Action to take
# If you're programmatically creating and mounting file systems, 
# # for example with an AWS CloudFormation template, we recommend that you implement a wait condition.
resource "time_sleep" "wait_efs_mount_target_dns_records_to_propagate" {
  create_duration = "90s"
  depends_on = [
    aws_efs_mount_target.a,
    aws_efs_mount_target.b,
    aws_efs_mount_target.c,
  ]
}
resource "aws_autoscaling_group" "ghost_ec2_pool" {
  name = "ghost_ec2_pool"
  launch_template {
    id      = aws_launch_template.ghost.id
    version = aws_launch_template.ghost.latest_version
  }
  min_size            = 3
  max_size            = 10
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id, aws_subnet.public_c.id]

  target_group_arns = [aws_lb_target_group.ghost-ec2.arn]

  health_check_grace_period = 180
  health_check_type         = "ELB"

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    # triggers = ["launch_template"] # default behaviour
  }
  depends_on = [
    time_sleep.wait_efs_mount_target_dns_records_to_propagate,
    aws_db_instance.ghost,
    # instance user_data script reads load balancer DNS name
    aws_lb.ghost-app,

    # trying to fix "efs/db racing" with ecs tasks
    time_sleep.wait_ecs_service_started
  ]
}

resource "time_sleep" "wait_ecs_service_started" {
  create_duration = "180s"
  depends_on = [
    aws_ecs_service.ghost
  ]
}

data "aws_instances" "asg_instances" {
  instance_state_names = ["pending", "running"]
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.ghost_ec2_pool.name
  }
}
