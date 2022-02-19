output alb-dns {
  value       = "http://${module.alb.alb-dns-name}"
  description = "description"
}
