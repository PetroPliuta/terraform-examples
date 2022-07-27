output "alb_dns_name" {
    value = "http://${aws_lb.ghost-app.dns_name}"
}
output "bastion_ssh" {
    value = "ssh ec2-user@${aws_instance.bastion.public_ip}"
}