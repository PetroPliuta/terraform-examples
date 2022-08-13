resource "aws_security_group" "vpc_endpoint" {
  vpc_id = aws_vpc.cloudx.id
  name   = "vpc_endpoint"
  # TODO: add rules
  ingress {
    protocol        = "-1"
    from_port       = 0
    to_port         = 0
    security_groups = [aws_security_group.fargate_pool.id, aws_security_group.bastion.id, aws_security_group.ec2_pool.id]
  }
  egress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0
    # security_groups = [aws_security_group.]
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "vpc_endpoint"
  }
}

# SSM, ECR, EFS, S3, CloudWatch and CloudWatch logs
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.cloudx.id
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
  service_name        = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.cloudx.id
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.cloudx.id
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "efs" {
  vpc_id              = aws_vpc.cloudx.id
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
  service_name        = "com.amazonaws.us-east-1.elasticfilesystem"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.cloudx.id
  service_name = "com.amazonaws.us-east-1.s3"
  # subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
  # vpc_endpoint_type = "Interface"
  # security_group_ids = [aws_security_group.vpc_endpoint.id]
  # private_dns_enabled = true

  route_table_ids = [aws_route_table.private_rt.id, aws_route_table.public_rt.id]
}
resource "aws_vpc_endpoint" "cloudwatch" {
  vpc_id              = aws_vpc.cloudx.id
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
  service_name        = "com.amazonaws.us-east-1.monitoring"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.cloudx.id
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}

