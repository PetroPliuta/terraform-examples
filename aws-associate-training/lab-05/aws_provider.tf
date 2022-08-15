provider "aws" {
  profile = "acloudguru"
  region  = "us-east-1"

  default_tags {
    tags = {
      Creator = "Petro Pliuta"
      Project = "aws training"
    }
  }
}
data "aws_region" "current" {}
