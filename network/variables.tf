variable name {
  type        = string
  default     = "my-vpc"
  description = "VPC name"
}
variable cidr {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC IP block"
}
variable tags {
  type        = map
  default     = {}
  description = "Tags"
}
