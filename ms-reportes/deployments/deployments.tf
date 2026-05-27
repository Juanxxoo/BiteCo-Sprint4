terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── Variables ─────────────────────────────────────────────────────────────────

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefijo para nombrar recursos"
  type        = string
  default     = "biteco-sprint4"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Nombre del key pair para SSH"
  type        = string
}

variable "repository_url" {
  description = "URL del repositorio Git"
  type        = string
  default     = "https://github.com/Juanxxoo/BiteCo-Sprint4.git"
}

variable "repository_branch" {
  description = "Rama a desplegar"
  type        = string
  default     = "main"
}

# ── Provider ──────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.region
}

# ── AMI Ubuntu ────────────────────────────────────────────────────────────────

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

# ── Security Groups ───────────────────────────────────────────────────────────

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

  tags = { Name = "${var.project_prefix}-ssh" }
}

resource "aws_security_group" "reportes" {
  name        = "${var.project_prefix}-reportes"
  description = "Trafico hacia ms-reportes puerto 8000"

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-reportes" }
}

resource "aws_security_group" "mongo" {
  name        = "${var.project_prefix}-mongo"
  description = "Trafico MongoDB puerto 27017 solo desde ms-reportes"

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.reportes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-mongo" }
}

# ── EC2 MongoDB ───────────────────────────────────────────────────────────────

resource "aws_instance" "mongo" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.mongo.id,
    aws_security_group.ssh.id
  ]

  user_data = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker

    docker run -d \
      --name mongo \
      --restart always \
      -p 27017:27017 \
      mongo:6.0
  EOT

  tags = { Name = "${var.project_prefix}-mongo", Role = "database" }
}

# ── EC2 ms-reportes ───────────────────────────────────────────────────────────

resource "aws_instance" "reportes" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.reportes.id,
    aws_security_group.ssh.id
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
    cd BiteCo-Sprint4/ms-reportes

    docker build -t ms-reportes .

    docker run -d \
      --name ms-reportes \
      --restart always \
      -p 8000:8000 \
      -e DJANGO_SECRET_KEY=ms-reportes-secret-sprint4 \
      -e DEBUG=False \
      -e ALLOWED_HOSTS=* \
      -e MONGO_HOST=${aws_instance.mongo.private_ip} \
      -e MONGO_PORT=27017 \
      -e MONGO_DB=biteco_reports \
      -e JWT_SECRET=biteco-secret-sprint4 \
      ms-reportes
  EOT

  depends_on = [aws_instance.mongo]

  tags = { Name = "${var.project_prefix}-reportes", Role = "ms-reportes" }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "reportes_public_ip" {
  description = "IP publica de ms-reportes"
  value       = aws_instance.reportes.public_ip
}

output "mongo_private_ip" {
  description = "IP privada de MongoDB"
  value       = aws_instance.mongo.private_ip
}

output "health_check_url" {
  description = "URL para validar que el servicio esta arriba"
  value       = "http://${aws_instance.reportes.public_ip}:8000/health/"
}

output "compare_consumption_url" {
  description = "URL del ASR de latencia"
  value       = "http://${aws_instance.reportes.public_ip}:8000/reports/compare-consumption/?project_id=project-001"
}
