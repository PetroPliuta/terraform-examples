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



resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.cloudx.id
  tags = {
    "Name" = "private_rt"
  }
}

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

