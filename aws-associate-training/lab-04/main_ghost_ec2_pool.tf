

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
  filename = "${path.module}/files/ghost-init-script.sh"
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

data "aws_instances" "asg_instances" {
  instance_state_names = ["pending", "running"]
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.ghost_ec2_pool.name
  }
}
