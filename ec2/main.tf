# ami
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# ec2 instance
resource "random_shuffle" "subnet" {
  input        = var.subnets
  result_count = var.instances-count
}

resource "aws_instance" "my-instance" {
  count = var.instances-count

  ami = data.aws_ami.ubuntu.id 
  instance_type = var.instance-type
  subnet_id = element(random_shuffle.subnet.result, count.index )
  # subnet_id = join("",random_shuffle.subnet.result)
  user_data = var.user-data 
  # security_groups = [var.ec2-sg]
  vpc_security_group_ids = [var.ec2-sg]
  tags = {
      ec2-id = random_string.ec2-id.result
  }
}

resource "random_string" "ec2-id" {
  length           = 16
  special          = false
}
