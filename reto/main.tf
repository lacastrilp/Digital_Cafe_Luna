terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Existentes (NO administrados por Terraform)
data "aws_subnet" "base" {
  id = var.subnet_id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Creados por el reto
resource "aws_security_group" "reto" {
  name        = "${var.prefix}-sg"
  description = "SG del reto Terraform"
  vpc_id      = data.aws_subnet.base.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_sqs_queue" "reto" {
  name = "${var.prefix}-queue"
}

resource "aws_instance" "reto" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.reto.id]
  iam_instance_profile   = var.instance_profile

  tags = {
    Name = "${var.prefix}-ec2"
  }
}
