

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

locals {
  extra_tag = "extra-tag"
}

resource "aws_instance" "example" {
  ami           = "ami-0567589d25e06853e" # Ubuntu 20.04 LTS // us-east-1
  instance_type = "t3.micro"
  subnet_id     = "subnet-0294d7d13be38590f"
  tags = {
    ExtraTag = local.extra_tag
  }
}