# Solución del Lab 5: versión corregida de labs/05-auditoria/terraform/main.tf
# Verificación: trivy config soluciones/  (no se despliega en ningún proveedor)

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

variable "red_administracion" {
  description = "Rango de la VPN o del bastión desde el que se permite SSH"
  type        = string
  default     = "10.10.0.0/24"
}

# --- Cifrado con clave gestionada por el cliente -------------------------
resource "aws_kms_key" "datos" {
  description         = "Clave para cifrar los datos del taller"
  enable_key_rotation = true
}

# --- Almacenamiento -------------------------------------------------------
# Excepciones justificadas para el contenedor que RECIBE los registros:
#  - AWS-0089: no puede registrar sus propios accesos en sí mismo (bucle).
#  - AWS-0132: S3 no admite SSE-KMS en el destino de los registros de acceso; usa SSE-S3.
#trivy:ignore:AWS-0089
#trivy:ignore:AWS-0132
resource "aws_s3_bucket" "registros" {
  bucket = "taller-registros-acceso"
}

resource "aws_s3_bucket" "fotos_clientes" {
  bucket = "taller-fotos-clientes"
}

# Corrección: bloqueo de acceso público activado
resource "aws_s3_bucket_public_access_block" "fotos_clientes" {
  bucket                  = aws_s3_bucket.fotos_clientes.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "registros" {
  bucket                  = aws_s3_bucket.registros.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Corrección: cifrado en reposo con KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "fotos_clientes" {
  bucket = aws_s3_bucket.fotos_clientes.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.datos.arn
    }
  }
}

# El destino de los registros de acceso usa SSE-S3 (SSE-KMS no es compatible como destino)
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "registros" {
  bucket = aws_s3_bucket.registros.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Corrección: versionado (defensa contra borrado y ransomware)
resource "aws_s3_bucket_versioning" "fotos_clientes" {
  bucket = aws_s3_bucket.fotos_clientes.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "registros" {
  bucket = aws_s3_bucket.registros.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Corrección: registro de accesos
resource "aws_s3_bucket_logging" "fotos_clientes" {
  bucket        = aws_s3_bucket.fotos_clientes.id
  target_bucket = aws_s3_bucket.registros.id
  target_prefix = "fotos-clientes/"
}

# --- Red ------------------------------------------------------------------
resource "aws_security_group" "servidor_web" {
  name        = "servidor-web"
  description = "Servidor web del taller"

  # Corrección: SSH solo desde la red de administración
  ingress {
    description = "SSH desde la VPN o el bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.red_administracion]
  }

  # Puerto público justificado: el servicio web debe ser accesible desde Internet
  ingress {
    description = "HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # trivy:ignore:AWS-0107
  }

  # Corrección: salida limitada a HTTPS dentro de la VPC
  egress {
    description = "HTTPS hacia servicios internos"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}

# --- Cómputo --------------------------------------------------------------
resource "aws_instance" "web" {
  ami                    = "ami-0123456789abcdef0"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.servidor_web.id]

  # Corrección: IMDSv2 obligatorio
  metadata_options {
    http_tokens = "required"
  }

  # Corrección: disco raíz cifrado
  root_block_device {
    encrypted = true
  }

  # Corrección: sin secretos en user_data; la aplicación los lee de Secrets Manager
  user_data = <<-EOT
    #!/bin/bash
    # La aplicación obtiene su credencial de Secrets Manager con el rol de la instancia
    systemctl start app
  EOT
}

# --- Identidad ------------------------------------------------------------
# Corrección: acciones y recursos concretos (Trivy NO detectaba el comodín original)
resource "aws_iam_policy" "app" {
  name = "app-politica"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/app/base-datos-*"
    }]
  })
}
