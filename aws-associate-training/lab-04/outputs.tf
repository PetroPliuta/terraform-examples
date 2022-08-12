output "alb_dns_name" {
  value = "http://${aws_lb.ghost-app.dns_name}"
}
output "bastion_ssh" {
  value = "ssh ec2-user@${aws_instance.bastion.public_ip}"
}
output "asg_instances_ssh" {
  value = [for s in data.aws_instances.asg_instances.private_ips: "ssh -J ec2-user@${aws_instance.bastion.public_ip} ec2-user@${s}"]
}
output "db_host" {
  value = aws_db_instance.ghost.endpoint
}
output "docker_repository_url" {
  value = aws_ecr_repository.ghost.repository_url
}
# output "docker_repository_registry_id" {
#   value = aws_ecr_repository.ghost.registry_id
# }
# output "region" {
#   value = data.aws_region.current.name
# }