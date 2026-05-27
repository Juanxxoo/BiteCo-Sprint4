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

resource "aws_security_group" "proyectos_ssh" {
  name        = "${var.project_prefix}-proyectos-ssh"
  description = "SSH access para ms-proyectos"

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

  tags = { Name = "${var.project_prefix}-proyectos-ssh" }
}

resource "aws_security_group" "proyectos" {
  name        = "${var.project_prefix}-proyectos"
  description = "Trafico hacia ms-proyectos puerto 8080"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-proyectos" }
}

resource "aws_security_group" "proyectos_postgres" {
  name        = "${var.project_prefix}-proyectos-postgres"
  description = "PostgreSQL solo desde ms-proyectos"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.proyectos.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-proyectos-postgres" }
}

resource "aws_instance" "proyectos_postgres" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.proyectos_postgres.id,
    aws_security_group.proyectos_ssh.id
  ]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
    docker run -d --name postgres --restart always -p 5432:5432 \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD=postgres \
      -e POSTGRES_DB=biteco_proyectos \
      postgres:15
  EOT

  tags = { Name = "${var.project_prefix}-proyectos-postgres", Role = "database" }
}

resource "aws_instance" "proyectos" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.proyectos.id,
    aws_security_group.proyectos_ssh.id
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
    cd BiteCo-Sprint4/ms-proyectos
    docker build -t ms-proyectos .
    docker run -d --name ms-proyectos --restart always -p 8080:8080 \
      -e PORT=8080 \
      -e POSTGRES_HOST=${aws_instance.proyectos_postgres.private_ip} \
      -e POSTGRES_PORT=5432 \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD=postgres \
      -e POSTGRES_DB=biteco_proyectos \
      ms-proyectos
  EOT

  depends_on = [aws_instance.proyectos_postgres]

  tags = { Name = "${var.project_prefix}-proyectos", Role = "ms-proyectos" }
}

output "proyectos_public_ip" {
  value = aws_instance.proyectos.public_ip
}

output "proyectos_postgres_private_ip" {
  value = aws_instance.proyectos_postgres.private_ip
}

output "health_check_url" {
  value = "http://${aws_instance.proyectos.public_ip}:8080/health"
}

output "projects_url" {
  value = "http://${aws_instance.proyectos.public_ip}:8080/projects"
}
