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
