output alb-dns-name {
    value = aws_lb.my-alb.dns_name
    description = "ALB DNS name"
}