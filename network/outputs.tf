output ec2-private-subnets {
  value       = [ aws_subnet.private-1.id, aws_subnet.private-2.id ]
  description = "private subnets for ec2 instances"
}
output ec2-public-subnets {
  value       = [ aws_subnet.public-1.id, aws_subnet.public-2.id ]
  description = "public subnets for ec2 instances"
}

output alb-sg {
  value       = aws_security_group.alb.id
  description = "security group for ALB"
}
output ec2-sg {
  value       = aws_security_group.ec2.id
  description = "security group for ec2"
}

output vpc-id {
  value       = aws_vpc.my-vpc.id
  description = "description"
}
