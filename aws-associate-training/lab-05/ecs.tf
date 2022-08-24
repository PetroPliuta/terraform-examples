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
# resource "aws_security_group_rule" "fargate_pool_rule_1" {
#   security_group_id        = aws_security_group.fargate_pool.id
#   type                     = "ingress"
#   protocol                 = "TCP"
#   from_port                = 2049
#   to_port                  = 2049
#   source_security_group_id = aws_security_group.efs.id
# }
resource "aws_security_group_rule" "fargate_pool_rule_2" {
  security_group_id        = aws_security_group.fargate_pool.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 2368
  to_port                  = 2368
  source_security_group_id = aws_security_group.alb.id
}
resource "aws_security_group_rule" "fargate_pool_rule_3" {
  security_group_id        = aws_security_group.fargate_pool.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 2368
  to_port                  = 2368
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_ecr_repository" "ghost" {
  name         = "ghost"
  force_delete = true
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
          Service = [
            "ec2.amazonaws.com",
            "ecs.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
      },
    ]
  })
  inline_policy {
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
            "elasticfilesystem:ClientWrite",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:CreateLogGroup"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = {
    Name = "ghost_ecs"
  }
}

# needed ?
# resource "aws_iam_instance_profile" "ghost_ecs" {
#   name = "ghost_ecs"
#   role = aws_iam_role.ghost_ecs.name
#   tags = {
#     Name = "ghost_ecs"
#   }
# }

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

data "template_file" "container_definitions" {
  template = file("${path.module}/files/container_definitions.tpl")
  vars = {
    ECR_IMAGE = "${aws_ecr_repository.ghost.repository_url}"
    DB_URL    = aws_db_instance.ghost.address
    DB_NAME   = aws_db_instance.ghost.db_name
    DB_USER   = aws_db_instance.ghost.username
    DB_PASS   = var.database_master_password

    CONTAINER_PATH = "/var/lib/ghost/content"
    # CONTAINER_PATH = "/var/lib/ghost"
    awslogs_group  = "ghost-fargate"
    awslogs_region = data.aws_region.current.name
  }
}

resource "aws_ecs_task_definition" "task_def_ghost" {
  family                   = "task_def_ghost"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.ghost_ecs.arn
  execution_role_arn       = aws_iam_role.ghost_ecs.arn
  # task_role_arn = aws_iam_role.bastion.arn
  # execution_role_arn = aws_iam_role.bastion.arn
  network_mode = "awsvpc"
  memory       = 1024
  cpu          = 256
  volume {
    name = "ghost_volume"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.ghost_content.id
    }
  }
  container_definitions = data.template_file.container_definitions.rendered

  # depends_on = [
  #   aws_db_instance.ghost,
  #   aws_ecr_repository.ghost
  # ]
}

resource "aws_ecs_service" "ghost" {
  # count = 0
  name            = "ghost"
  cluster         = aws_ecs_cluster.ghost.id
  task_definition = aws_ecs_task_definition.task_def_ghost.id
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
    assign_public_ip = false
    security_groups  = [aws_security_group.fargate_pool.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ghost-fargate.arn
    container_name   = "ghost_container"
    container_port   = 2368
  }

  depends_on = [
    aws_db_instance.ghost, # container connects to db
    aws_instance.bastion,  # bastion instance creates/pushes Docker image
    aws_vpc_endpoint.efs,
    time_sleep.wait_efs_mount_target_dns_records_to_propagate
  ]
}
