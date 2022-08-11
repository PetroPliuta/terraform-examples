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
resource "aws_security_group" "efs" {
  name        = "efs"
  description = "defines access to efs mount points"
  vpc_id      = aws_vpc.cloudx.id
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_pool.id, aws_security_group.fargate_pool.id]
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
          "elasticloadbalancing:DescribeLoadBalancers"
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

resource "aws_lb" "ghost-app" {
  name               = "ghost-app"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id, aws_subnet.public_c.id]
}

resource "aws_lb_target_group" "ghost-ec2" {
  name     = "ghost-ec2"
  port     = 2368
  protocol = "HTTP"
  vpc_id   = aws_vpc.cloudx.id
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 6
  }

  tags = {
    "Name" = "ghost-ec2"
  }
}
resource "aws_lb_target_group" "ghost-fargate" {
  name     = "ghost-fargate"
  port     = 2368
  protocol = "HTTP"
  vpc_id   = aws_vpc.cloudx.id
  # health_check {
  #   healthy_threshold   = 3
  #   unhealthy_threshold = 3
  #   timeout             = 5
  #   interval            = 6
  # }

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

  user_data = data.local_file.ghost-init-script.content_base64
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
  }
  depends_on = [
    time_sleep.wait_efs_mount_target_dns_records_to_propagate,
    aws_db_instance.ghost,
    # instance user_data script reads load balancer DNS name
    aws_lb.ghost-app
  ]
}


# Bastion

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon2-linux-latest.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ghost-ec2-pool.key_name
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  tags = {
    "Name" = "bastion"
  }
}

data "aws_instances" "asg_instances" {
  instance_state_names = ["pending", "running"]
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.ghost_ec2_pool.name
  }
}


# DB RDS

resource "aws_subnet" "private_db_a" {
  vpc_id            = aws_vpc.cloudx.id
  cidr_block        = "10.10.20.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private_db_a"
  }
}
resource "aws_subnet" "private_db_b" {
  vpc_id            = aws_vpc.cloudx.id
  cidr_block        = "10.10.21.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private_db_b"
  }
}
resource "aws_subnet" "private_db_c" {
  vpc_id            = aws_vpc.cloudx.id
  cidr_block        = "10.10.22.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "private_db_c"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.cloudx.id
}

resource "aws_route_table_association" "private_rt_db_a" {
  subnet_id      = aws_subnet.private_db_a.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_rt_db_b" {
  subnet_id      = aws_subnet.private_db_b.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_rt_db_c" {
  subnet_id      = aws_subnet.private_db_c.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "mysql" {
  vpc_id      = aws_vpc.cloudx.id
  name        = "mysql"
  description = "defines access to ghost db"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_pool.id, aws_security_group.fargate_pool.id]
  }
  lifecycle {
    # Necessary if changing 'name' or 'name_prefix' properties.
    create_before_destroy = true
  }

  tags = {
    "Name" = "mysql"
  }
}

resource "aws_db_subnet_group" "ghost" {
  name        = "ghost"
  description = "ghost database subnet group"
  subnet_ids  = [aws_subnet.private_db_a.id, aws_subnet.private_db_b.id, aws_subnet.private_db_c.id]
  tags = {
    "Name" = "ghost"
  }
}

resource "aws_db_instance" "ghost" {
  identifier     = "ghost"
  instance_class = "db.t2.micro"

  allocated_storage           = 20
  allow_major_version_upgrade = true
  apply_immediately           = true
  db_name                     = "ghost"
  db_subnet_group_name        = aws_db_subnet_group.ghost.name
  engine                      = "mysql"
  engine_version              = "8.0"
  skip_final_snapshot         = true
  username                    = "awsuser"
  password                    = aws_ssm_parameter.db_password.value
  vpc_security_group_ids      = [aws_security_group.mysql.id]

}

resource "aws_ssm_parameter" "db_password" {
  name  = "/ghost/dbpassw"
  type  = "SecureString"
  value = var.database_master_password
}



### LAB 04
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.cloudx.id
  cidr_block        = "10.10.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name" = "private_a"
  }
}
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.cloudx.id
  cidr_block        = "10.10.11.0/24"
  availability_zone = "us-east-1b"

  tags = {
    "Name" = "private_b"
  }
}
resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.cloudx.id
  cidr_block        = "10.10.12.0/24"
  availability_zone = "us-east-1c"

  tags = {
    "Name" = "private_c"
  }
}

resource "aws_route_table_association" "private_rt_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_rt_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_rt_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "fargate_pool" {
  vpc_id      = aws_vpc.cloudx.id
  name        = "fargate_pool"
  description = "Allows access for Fargate instances"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "fargate_pool"
  }
}
resource "aws_security_group_rule" "fargate_pool_rule_1" {
  security_group_id        = aws_security_group.fargate_pool.id
  type                     = "ingress"
  protocol                 = "TCP"
  from_port                = 2049
  to_port                  = 2049
  source_security_group_id = aws_security_group.efs.id
}
resource "aws_security_group_rule" "fargate_pool_rule_2" {
  security_group_id        = aws_security_group.fargate_pool.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 2368
  to_port                  = 2368
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_ecr_repository" "ghost" {
  name = "ghost"
}


resource "aws_iam_policy" "ghost_ecs" {
  name = "ghost_ecs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
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
    Name = "ghost_ecs"
  }
}

resource "aws_iam_role" "ghost_ecs" {
  name = "ghost_ecs"
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
  managed_policy_arns = [aws_iam_policy.ghost_ecs.arn]

  tags = {
    Name = "ghost_ecs"
  }
}

resource "aws_iam_instance_profile" "ghost_ecs" {
  name = "ghost_ecs"
  role = aws_iam_role.ghost_ecs.name
  tags = {
    Name = "ghost_ecs"
  }
}


# VPC endpoints

resource "aws_security_group" "vpc_endpoint" {
  vpc_id = aws_vpc.cloudx.id
  name   = "vpc_endpoint"
  # TODO: add rules
  ingress {
    protocol        = "tcp"
    from_port       = 0
    to_port         = 0
    security_groups = [aws_security_group.fargate_pool.id]
  }
  # egress {
  #   protocol = "tcp"
  #   from_port = 0
  #   to_port = 0
  #   security_groups = [aws_security_group.]
  # }
  tags = {
    "Name" = "vpc_endpoint"
  }
}

# SSM, ECR, EFS, S3, CloudWatch and CloudWatch logs
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint.id]
}
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint.id]
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint.id]
}
resource "aws_vpc_endpoint" "efs" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.us-east-1.elasticfilesystem"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint.id]
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.cloudx.id
  service_name = "com.amazonaws.us-east-1.s3"
  # vpc_endpoint_type = "Interface"
  # security_group_ids = [aws_security_group.vpc_endpoint.id]
  route_table_ids = [aws_route_table.private_rt.id]
}
resource "aws_vpc_endpoint" "cloudwatch" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.us-east-1.monitoring"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint.id]
}
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint.id]
}


# ECS cluster

resource "aws_ecs_cluster" "ghost" {
  name = "ghost"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    "Name" = "ghost"
  }
}

resource "aws_ecs_task_definition" "task_def_ghost" {
  family                   = "task_def_ghost"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.ghost_ecs.arn
  execution_role_arn       = aws_iam_role.ghost_ecs.arn
  network_mode             = "awsvpc"
  memory                   = 1024
  cpu                      = 256
  volume {
    name = "ghost_volume"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.ghost_content.id
    }
  }

  container_definitions = [
    {
      "name" : "ghost_container",
      "image" : "${aws_ecr_repository.ghost.repository_url}/ghost:4.12",
      "essential" : true,
      "environment" : [
        { "name" : "database__client", "value" : "mysql" },
        { "name" : "database__connection__host", "value" : "${aws_db_instance.ghost.address}" },
        { "name" : "database__connection__user", "value" : "${aws_db_instance.ghost.username}" },
        { "name" : "database__connection__password", "value" : "${aws_db_instance.ghost.password}" },
        { "name" : "database__connection__database", "value" : "${aws_db_instance.ghost.db_name}" }
      ],
      "mountPoints" : [
        {
          "containerPath" : "/var/lib/ghost/content",
          "sourceVolume" : "ghost_volume"
        }
      ],
      "portMappings" : [
        {
          "containerPort" : 2368,
          "hostPort" : 2368
        }
      ]
    }
  ]

  depends_on = [
    aws_db_instance.ghost,
    aws_ecr_repository.ghost
  ]
}
# aws --profile acloudguru elbv2 describe-target-health --target-group-arn $(aws --profile acloudguru elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' --output text) --query 'TargetHealthDescriptions[].TargetHealth.State'

