#vpc
resource "aws_vpc" "my-vpc"{
    cidr_block = var.cidr
    tags = var.tags
}
# azs
data "aws_availability_zones" "available" {
#   state = "available"
    filter {
        name   = "opt-in-status"
        values = ["opt-in-not-required"]
    }
}

# subnets
resource "aws_subnet" "public-1" {
    vpc_id=aws_vpc.my-vpc.id
    cidr_block = cidrsubnet(aws_vpc.my-vpc.cidr_block, 8, 0)
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true
    tags = {
        Name = "public-1"
    }
}
resource "aws_subnet" "public-2" {
    vpc_id=aws_vpc.my-vpc.id
    cidr_block = cidrsubnet(aws_vpc.my-vpc.cidr_block, 8, 1)
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = true
    tags = {
        Name = "public-2"
    }
}
resource "aws_subnet" "private-1" {
    vpc_id=aws_vpc.my-vpc.id
    cidr_block = cidrsubnet(aws_vpc.my-vpc.cidr_block, 8, 10)
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = false
    tags = {
        Name = "private-1"
    }
}
resource "aws_subnet" "private-2" {
    vpc_id=aws_vpc.my-vpc.id
    cidr_block = cidrsubnet(aws_vpc.my-vpc.cidr_block, 8, 11)
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = false
    tags = {
        Name = "private-2"
    }
}

# igw
resource "aws_internet_gateway" "my-igw"{
    vpc_id = aws_vpc.my-vpc.id
    tags = {
        Name = "my-igw"
    }
}

# nat gw
resource "aws_eip" "nat-gw-ip"{
    tags = {
        Name = "nat-gw ip"
    }
}
resource "aws_nat_gateway" "my-nat-gw"{
    allocation_id = aws_eip.nat-gw-ip.id
    subnet_id = aws_subnet.public-1.id
    tags = {
        Name = "my-nat-gw"
    }
    depends_on = [aws_internet_gateway.my-igw]
}

# routing tables
resource "aws_route_table" "public"{
    vpc_id = aws_vpc.my-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my-igw.id
    }
    tags={
        Name = "public"
    }
}
resource "aws_route_table" "private"{
    vpc_id = aws_vpc.my-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.my-nat-gw.id
    }
    tags={
        Name = "private"
    }
}
# route table associations
resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private-1" {
  subnet_id      = aws_subnet.private-1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private-2" {
  subnet_id      = aws_subnet.private-2.id
  route_table_id = aws_route_table.private.id
}

# alb sg
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Allow inbound traffic for ALB"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ALB-sg"
  }
}

# ec2 sg
resource "aws_security_group" "ec2" {
  name        = "ec2-sg"
  description = "Allow inbound traffic for EC2"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "EC2-sg"
  }
}