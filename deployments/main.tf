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

resource "aws_security_group" "ssh" {
  name        = "${var.project_prefix}-ssh"
  description = "SSH access"

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
}

resource "aws_security_group" "public_services" {
  name        = "${var.project_prefix}-public-services"
  description = "Public access to experiment endpoints"

  ingress {
    from_port   = 8000
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

resource "aws_security_group" "internal_db" {
  name        = "${var.project_prefix}-internal-db"
  description = "Internal database access"

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "postgres_proyectos" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh.id, aws_security_group.internal_db.id]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker

    docker run -d --name postgres-proyectos --restart always -p 5432:5432 \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD=postgres \
      -e POSTGRES_DB=biteco_proyectos \
      postgres:15
  EOT

  tags = {
    Name = "${var.project_prefix}-postgres-proyectos"
  }
}

resource "aws_instance" "mongo_reportes" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh.id, aws_security_group.internal_db.id]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker

    docker run -d --name mongo-reportes --restart always -p 27017:27017 mongo:7
  EOT

  tags = {
    Name = "${var.project_prefix}-mongo-reportes"
  }
}

resource "aws_instance" "mongo_alertas" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh.id, aws_security_group.internal_db.id]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker

    docker run -d --name mongo-alertas --restart always -p 27017:27017 mongo:7
  EOT

  tags = {
    Name = "${var.project_prefix}-mongo-alertas"
  }
}

resource "aws_instance" "ms_proyectos" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh.id, aws_security_group.public_services.id]

  user_data = <<-EOT
    #!/bin/bash
    set -e
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
      -e POSTGRES_HOST=${aws_instance.postgres_proyectos.private_ip} \
      -e POSTGRES_PORT=5432 \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD=postgres \
      -e POSTGRES_DB=biteco_proyectos \
      ms-proyectos
  EOT

  depends_on = [aws_instance.postgres_proyectos]

  tags = {
    Name = "${var.project_prefix}-ms-proyectos"
  }
}

resource "aws_instance" "ms_alertas" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh.id, aws_security_group.public_services.id]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y docker.io git
    systemctl enable docker
    systemctl start docker

    cd /home/ubuntu
    git clone -b ${var.repository_branch} ${var.repository_url} BiteCo-Sprint4
    cd BiteCo-Sprint4/ms-alertas

    docker build -t ms-alertas .
    docker run -d --name ms-alertas --restart always -p 3000:3000 \
      -e MONGO_HOST=${aws_instance.mongo_alertas.private_ip} \
      -e MONGO_PORT=27017 \
      -e MONGO_DB=biteco_alerts \
      ms-alertas
  EOT

  depends_on = [aws_instance.mongo_alertas]

  tags = {
    Name = "${var.project_prefix}-ms-alertas"
  }
}

resource "aws_instance" "ms_reportes" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh.id, aws_security_group.public_services.id]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y docker.io git
    systemctl enable docker
    systemctl start docker

    cd /home/ubuntu
    git clone -b ${var.repository_branch} ${var.repository_url} BiteCo-Sprint4
    cd BiteCo-Sprint4/ms-reportes

    docker build -t ms-reportes .
    docker run -d --name ms-reportes --restart always -p 8000:8000 \
      -e MONGO_HOST=${aws_instance.mongo_reportes.private_ip} \
      -e MONGO_PORT=27017 \
      -e MONGO_DB=biteco_reports \
      -e PROJECTS_SERVICE_URL=http://${aws_instance.ms_proyectos.private_ip}:8080 \
      -e ALERTS_SERVICE_URL=http://${aws_instance.ms_alertas.private_ip}:3000 \
      ms-reportes
  EOT

  depends_on = [
    aws_instance.mongo_reportes,
    aws_instance.ms_proyectos,
    aws_instance.ms_alertas
  ]

  tags = {
    Name = "${var.project_prefix}-ms-reportes"
  }
}

output "ms_reportes_url" {
  value = "http://${aws_instance.ms_reportes.public_ip}:8000"
}

output "ms_proyectos_url" {
  value = "http://${aws_instance.ms_proyectos.public_ip}:8080"
}

output "ms_alertas_url" {
  value = "http://${aws_instance.ms_alertas.public_ip}:3000"
}

output "latency_test_url" {
  value = "http://${aws_instance.ms_reportes.public_ip}:8000/reports/compare-consumption/?project_id=project-001"
}

output "security_tamper_url" {
  value = "http://${aws_instance.ms_reportes.public_ip}:8000/reports/tamper/"
}

output "security_integrity_url" {
  value = "http://${aws_instance.ms_reportes.public_ip}:8000/reports/integrity/check/"
}