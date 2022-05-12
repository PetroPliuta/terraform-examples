output ec2-id-tag {
  value       = random_string.ec2-id.result
  description = "description"
}

output instances-count{
  value = var.instances-count
}