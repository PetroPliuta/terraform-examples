provider "aws" {
  profile = "acloudguru"
  region  = "us-east-1"

  default_tags {
    tags = {
      Creator = "Petro Pliuta"
      Project = "aws training"
    }
  }
}

# Use data construction for templates and scripts.
# Use output construction to accumulate data.

# Network stack

resource "aws_vpc" "cloudx" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Name" = "cloudx"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.cloudx.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    "Name" = "public_a"
  }
}
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.cloudx.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    "Name" = "public_b"
  }
}
resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.cloudx.id
  cidr_block              = "10.10.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    "Name" = "public_c"
  }
}
resource "aws_internet_gateway" "cloudx-igw" {
  vpc_id = aws_vpc.cloudx.id
  tags = {
    "Name" = "cloudx-igw"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cloudx.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloudx-igw.id
  }
  tags = {
    "Name" = "public_rt"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public_rt.id
}


# Security groups

# name=bastion, description="allows access to bastion":
# ingress rule_1: port=22, source={your_ip}, protocol=tcp
# egress rule_1: allows any destination
resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "allows access to bastion"
  vpc_id      = aws_vpc.cloudx.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    # Necessary if changing 'name' or 'name_prefix' properties.
    create_before_destroy = true
  }
  tags = {
    "Name" = "bastion"
  }
}

# name=ec2_pool, description="allows access to ec2 instances":
# ingress rule_1: port=22, source_security_group={bastion}, protocol=tcp
# ingress rule_2: port=2049, source={vpc_cidr}, protocol=tcp
# ingress rule_3: port=2368, source_security_group={alb}, protocol=tcp
# egress rule_1: allows any destination
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
  from_port         = 2049
  to_port           = 2049
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

# name=alb, description="allows access to alb":
# ingress rule_1: port=80, source={your_ip}, protocol=tcp
# egress rule_1: port=any, source_security_group={ec2_pool}, protocol=any
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
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.ec2_pool.id]
  }

  lifecycle {
    # Necessary if changing 'name' or 'name_prefix' properties.
    create_before_destroy = true
  }
  tags = {
    "Name" = "alb"
  }
}

# name=efs, description="defines access to efs mount points":
# ingress rule_1: port=2049, source_security_group={ec2_pool}, protocol=tcp
# egress rule_1: allows any destination to {vpc_cidr}
resource "aws_security_group" "efs" {
  name        = "efs"
  description = "defines access to efs mount points"
  vpc_id      = aws_vpc.cloudx.id
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_pool.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.cloudx.cidr_block]
  }

  lifecycle {
    # Necessary if changing 'name' or 'name_prefix' properties.
    create_before_destroy = true
  }
  tags = {
    "Name" = "efs"
  }
}


# SSH Key pair
resource "aws_key_pair" "ghost-ec2-pool" {
  public_key = var.ssh-key
  key_name   = "ghost-ec2-pool"
  tags = {
    Name = "ghost-ec2-pool"
  }
}


# IAM role
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
          "elasticfilesystem:ClientWrite"
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


# Elastic File System

resource "aws_efs_file_system" "ghost_content" {
  creation_token = "ghost_content"
  tags = {
    "Name" = "ghost_content"
  }
}
resource "aws_efs_mount_target" "a" {
  file_system_id  = aws_efs_file_system.ghost_content.id
  subnet_id       = aws_subnet.public_a.id
  security_groups = [aws_security_group.efs.id]
}
resource "aws_efs_mount_target" "b" {
  file_system_id  = aws_efs_file_system.ghost_content.id
  subnet_id       = aws_subnet.public_b.id
  security_groups = [aws_security_group.efs.id]
}
resource "aws_efs_mount_target" "c" {
  file_system_id  = aws_efs_file_system.ghost_content.id
  subnet_id       = aws_subnet.public_c.id
  security_groups = [aws_security_group.efs.id]
}


# Application load balancer

# aws_lb
# aws_lb_target_group
# aws_lb_listener
# aws_lb_listener_rule
resource "aws_lb" "ghost-app" {
  name               = "ghost-app"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id, aws_subnet.public_c.id]
}

# Create Application Load Balancer with 1 target group:
# target group 1: name=ghost-ec2,port=2368,protocol="HTTP"
resource "aws_lb_target_group" "ghost-ec2" {
  name     = "ghost-ec2"
  port     = 2368
  protocol = "HTTP"
  vpc_id   = aws_vpc.cloudx.id
  health_check {
    # healthy_threshold = 3
    # unhealthy_threshold = 3
    timeout = 5

    interval = 6
  }

  tags = {
    "Name" = "ghost-ec2"
  }
}

# Create ALB listener: port=80,protocol="HTTP", avalability zone=a,b,c
# Edit ALB listener rule: action type = "forward",target_group_1_weight=100
resource "aws_lb_listener" "ghost-ec2" {
  load_balancer_arn = aws_lb.ghost-app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ghost-ec2.arn
  }
}
# resource "aws_lb_listener_rule" "ghost-app" {
#   listener_arn = aws_lb_listener.ghost-ec2.arn

#   action {
#     type = "forward"
#     target_group_arn = aws_lb_target_group.ghost-ec2.arn
#   }
# }


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

data "local_file" "ghost-init-script" {
  filename = "${path.module}/ghost-init-script.sh"
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
  #   vpc_security_group_ids = [aws_security_group.ec2_pool.id]

  user_data = data.local_file.ghost-init-script.content_base64
}


# Auto-scaling group
# aws_autoscaling_group
#Create Auto-scaling group and assign it with Launch Template from step 5:
#name=ghost_ec2_pool
#avalability zone=a,b,c
#Attach ASG with {ghost-ec2} target group
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
  }
  depends_on = [
    aws_efs_mount_target.a,
    aws_efs_mount_target.b,
    aws_efs_mount_target.c,
  ]
}

# aws_autoscaling_attachment


# Bastion
# aws_instance

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon2-linux-latest.id
  associate_public_ip_address = true
  #   availability_zone = "us-east-1a"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ghost-ec2-pool.key_name
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  tags = {
    "Name" = "bastion"
  }
}

data "aws_instances" "asg_instances" {
  instance_state_names = ["pending", "running"]
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.ghost_ec2_pool.name
  }
  # aws:autoscaling:groupName	ghost_ec2_pool
}
