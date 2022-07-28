output "alb_dns_name" {
  value = "http://${aws_lb.ghost-app.dns_name}"
}
output "bastion_ssh" {
  value = "ssh ec2-user@${aws_instance.bastion.public_ip}"
}
output "asg_instances_ssh" {
  value = [for s in data.aws_instances.asg_instances.private_ips: "ssh -J ec2-user@${aws_instance.bastion.public_ip} ec2-user@${s}"]
}

