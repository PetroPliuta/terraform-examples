variable subnets {
  type        = list
  description = "ALB subnets"
}
variable alb-sg {
  type = string
  description = "ALB security group"
}
variable ec2-id-tag {
  type        = string
  description = "TAG to identify EC2 instances"
}
variable vpc-id {
  type = string
  description = "VPC ID for target group"
}

variable instances-count{
  type = number
  description = "count of ec2 instances"
}