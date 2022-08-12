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
