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