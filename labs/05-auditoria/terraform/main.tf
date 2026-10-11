# Infraestructura como código CON ERRORES A PROPÓSITO para el Lab 5.
# No se despliega: solo se analiza con "trivy config". El participante identifica y corrige los problemas.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- Almacenamiento -------------------------------------------------------
resource "aws_s3_bucket" "fotos_clientes" {
  bucket = "taller-fotos-clientes"
}

# Error: el bloqueo de acceso público está desactivado
resource "aws_s3_bucket_public_access_block" "fotos_clientes" {
  bucket                  = aws_s3_bucket.fotos_clientes.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Error: sin cifrado, sin versionado y sin registro de accesos (no hay recursos para ello)

# --- Red ------------------------------------------------------------------
resource "aws_security_group" "servidor_web" {
  name        = "servidor-web"
  description = "Servidor web del taller"

  # Error: SSH abierto a todo Internet
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Error: salida sin ninguna restricción
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Cómputo --------------------------------------------------------------
resource "aws_instance" "web" {
  ami                    = "ami-0123456789abcdef0"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.servidor_web.id]

  # Error: IMDSv1 permitido (robo de credenciales vía SSRF al servicio de metadatos)
  metadata_options {
    http_tokens = "optional"
  }

  # Error: disco raíz sin cifrar
  root_block_device {
    encrypted = false
  }

  # Error: secreto en texto plano dentro de user_data
  user_data = <<-EOT
    #!/bin/bash
    export DB_PASSWORD="SuperSecreta123"
    systemctl start app
  EOT
}

# --- Identidad ------------------------------------------------------------
resource "aws_iam_policy" "app" {
  name = "app-politica"

  # Error: comodín total
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}
