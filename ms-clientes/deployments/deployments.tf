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

variable "reports_service_url" {
  description = "URL publica de ms-reportes"
  type        = string
  default     = "http://98.91.195.110:8000"
}

variable "projects_service_url" {
  description = "URL publica de ms-proyectos"
  type        = string
  default     = "http://50.16.127.15:8080"
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

resource "aws_security_group" "clientes_ssh" {
  name        = "${var.project_prefix}-clientes-ssh"
  description = "SSH access para ms-clientes"

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

  tags = { Name = "${var.project_prefix}-clientes-ssh" }
}

resource "aws_security_group" "clientes" {
  name        = "${var.project_prefix}-clientes"
  description = "Trafico hacia ms-clientes puerto 8081"

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-clientes" }
}

resource "aws_security_group" "clientes_postgres" {
  name        = "${var.project_prefix}-clientes-postgres"
  description = "PostgreSQL solo desde ms-clientes"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.clientes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-clientes-postgres" }
}

resource "aws_instance" "clientes_postgres" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.clientes_postgres.id,
    aws_security_group.clientes_ssh.id
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
      -e POSTGRES_DB=biteco_clientes \
      postgres:15
  EOT

  tags = { Name = "${var.project_prefix}-clientes-postgres", Role = "database" }
}

resource "aws_instance" "clientes" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.clientes.id,
    aws_security_group.clientes_ssh.id
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
    cd BiteCo-Sprint4/ms-clientes
    docker build -t ms-clientes .
    docker run -d --name ms-clientes --restart always -p 8081:8081 \
      -e PORT=8081 \
      -e POSTGRES_HOST=${aws_instance.clientes_postgres.private_ip} \
      -e POSTGRES_PORT=5432 \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD=postgres \
      -e POSTGRES_DB=biteco_clientes \
      -e REPORTS_SERVICE_URL=${var.reports_service_url} \
      -e PROJECTS_SERVICE_URL=${var.projects_service_url} \
      ms-clientes
  EOT

  depends_on = [aws_instance.clientes_postgres]

  tags = { Name = "${var.project_prefix}-clientes", Role = "ms-clientes" }
}

output "clientes_public_ip" {
  value = aws_instance.clientes.public_ip
}

output "clientes_postgres_private_ip" {
  value = aws_instance.clientes_postgres.private_ip
}

output "health_check_url" {
  value = "http://${aws_instance.clientes.public_ip}:8081/health"
}

output "clients_url" {
  value = "http://${aws_instance.clientes.public_ip}:8081/clients"
}

output "tamper_url" {
  value = "http://${aws_instance.clientes.public_ip}:8081/clients/tamper-project-report"
}
