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


# Bastion

resource "aws_iam_role" "bastion" {
  name = "bastion"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "ec2.amazonaws.com"
          ]
        }
      },
    ]
  })
  inline_policy {
    name = "ecr"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:CompleteLayerUpload",
            "ecr:GetDownloadUrlForLayer",
            "ecr:InitiateLayerUpload",
            "ecr:PutImage",
            "ecr:UploadLayerPart"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = {
    Name = "bastion"
  }
}
resource "aws_iam_instance_profile" "bastion" {
  name = "bastion"
  role = aws_iam_role.bastion.id
  tags = {
    Name = "bastion"
  }
}

data "template_file" "bastion_user_data" {
  template = file("${path.module}/files/bastion-init-script.sh")
  vars = {
    DOCKER_IMAGE = "${aws_ecr_repository.ghost.repository_url}"
    REGION       = data.aws_region.current.name
    REGISTRY_ID  = aws_ecr_repository.ghost.registry_id
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon2-linux-latest.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ghost-ec2-pool.key_name
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.id

  user_data                   = data.template_file.bastion_user_data.rendered
  user_data_replace_on_change = true

  tags = {
    "Name" = "bastion"
  }
  depends_on = [
    aws_ecr_repository.ghost,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr
  ]
}
