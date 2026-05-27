terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_prefix" {
  type    = string
  default = "biteco-sprint4"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "key_name" {
  type = string
}

variable "repository_url" {
  type    = string
  default = "https://github.com/Juanxxoo/BiteCo-Sprint4.git"
}

variable "repository_branch" {
  type    = string
  default = "main"
}

provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "alertas_ssh" {
  name        = "${var.project_prefix}-alertas-ssh"
  description = "SSH access para ms-alertas"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-alertas-ssh" }
}

resource "aws_security_group" "alertas" {
  name        = "${var.project_prefix}-alertas"
  description = "Trafico hacia ms-alertas puerto 3000"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-alertas" }
}

resource "aws_security_group" "alertas_mongo" {
  name        = "${var.project_prefix}-alertas-mongo"
  description = "MongoDB solo desde ms-alertas"

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.alertas.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-alertas-mongo" }
}

resource "aws_instance" "alertas_mongo" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.alertas_mongo.id,
    aws_security_group.alertas_ssh.id
  ]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
    docker run -d --name mongo --restart always -p 27017:27017 mongo:6.0
  EOT

  tags = { Name = "${var.project_prefix}-alertas-mongo", Role = "database" }
}

resource "aws_instance" "alertas" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.alertas.id,
    aws_security_group.alertas_ssh.id
  ]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y docker.io git
    systemctl enable docker
    systemctl start docker
    cd /home/ubuntu
    git clone -b ${var.repository_branch} ${var.repository_url} BiteCo-Sprint4
    cd BiteCo-Sprint4/ms-alertas
    docker build -t ms-alertas .
    docker run -d --name ms-alertas --restart always -p 3000:3000 \
      -e DJANGO_SECRET_KEY=ms-alertas-secret-sprint4 \
      -e DEBUG=False \
      -e ALLOWED_HOSTS=* \
      -e MONGO_HOST=${aws_instance.alertas_mongo.private_ip} \
      -e MONGO_PORT=27017 \
      -e MONGO_DB=biteco_alerts \
      -e JWT_SECRET=biteco-secret-sprint4 \
      ms-alertas
  EOT

  depends_on = [aws_instance.alertas_mongo]

  tags = { Name = "${var.project_prefix}-alertas", Role = "ms-alertas" }
}

output "alertas_public_ip" {
  value = aws_instance.alertas.public_ip
}

output "alertas_mongo_private_ip" {
  value = aws_instance.alertas_mongo.private_ip
}

output "health_check_url" {
  value = "http://${aws_instance.alertas.public_ip}:3000/health/"
}

output "security_alerts_url" {
  value = "http://${aws_instance.alertas.public_ip}:3000/alerts/security/"
}

output "audit_log_url" {
  value = "http://${aws_instance.alertas.public_ip}:3000/alerts/audit-log/"
}
