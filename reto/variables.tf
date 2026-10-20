variable "region" {
  type    = string
  default = "us-east-1"
}

variable "prefix" {
  type    = string
  default = "reto-tf"
}

variable "subnet_id" {
  type        = string
  description = "Subnet publica existente de dcl-dev-vpc"
}

variable "ssh_cidr" {
  type        = string
  description = "Tu IP publica en formato CIDR, ej. 190.x.x.x/32"
}

variable "instance_profile" {
  type    = string
  default = null
}

