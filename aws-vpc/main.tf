# lab:
# vpc, subnets private, public,
# igw, nat gw, routing tables
# load balancer
# PHP static site
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }

  required_version = ">=1.0.0"

  backend "s3" {
    bucket = "tf-state-pliuta"
    key    = "state-file"
    region = "us-east-1"
  }
}
provider "aws" {
  region = "us-east-1"
}

module "net" {
  source = "./network"

  name = "my-vpc"
  cidr = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}
module "ec2" {
  source        = "./ec2"
  instance-type = "t3.micro"

  # subnets = module.net.ec2-public-subnets
  subnets = module.net.ec2-private-subnets

  instances-count = 2
  ec2-sg = module.net.ec2-sg

  depends_on = [module.net]
}
module "alb" {
  source = "./alb"
  subnets = module.net.ec2-public-subnets

  alb-sg = module.net.alb-sg
  ec2-id-tag = module.ec2.ec2-id-tag
  vpc-id = module.net.vpc-id

  instances-count = module.ec2.instances-count
  depends_on = [module.ec2]
}
