resource "aws_cloudwatch_dashboard" "ghost" {
  dashboard_name = "ghost"
  dashboard_body = file("${path.module}/files/dashboard.json")
}

# EC2 instances in ASG
# Average CPU Utilization

# ECS
# Service CPU Utilization
# Running Tasks Count

# EFS
# Client Connections
# Storage Bytes in Mb

# RDS
# Database Connections
# CPU Utilization
# Storage Read/Write IOPS
