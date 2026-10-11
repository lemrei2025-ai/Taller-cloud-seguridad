#!/usr/bin/env bash
# Instala todo lo necesario en Kali Linux. Ejecutar UNA vez, antes del taller, con internet.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "[x] Este script se ejecuta con el usuario normal (usará sudo cuando haga falta)." >&2
  exit 1
fi

echo "[*] Actualizando índices de paquetes..."
sudo apt-get update

echo "[*] Instalando Docker, AWS CLI y herramientas de seguridad..."
sudo apt-get install -y docker.io docker-compose awscli jq curl git nmap gitleaks trivy

echo "[*] Habilitando Docker y agregando a $USER al grupo docker..."
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

# "mc" también es Midnight Commander: se comprueba que sea el cliente de MinIO.
if ! mc --version 2>/dev/null | grep -qi minio; then
  echo "[*] Instalando el cliente de MinIO (mc)..."
  arq="$(dpkg --print-architecture)"   # amd64 o arm64
  tmp="$(mktemp -d)"
  if curl -fL "https://dl.min.io/client/mc/release/linux-${arq}/mc" -o "$tmp/mc"; then
    sudo install -m 0755 "$tmp/mc" /usr/local/bin/mc
  else
    echo "[!] No se pudo descargar mc. Alternativa: usa 'docker exec nube-minio mc ...'" >&2
  fi
  rm -rf "$tmp"
fi

echo "[*] Descargando imágenes del laboratorio (para trabajar sin internet el día del taller)..."
sudo docker pull minio/minio:RELEASE.2025-09-07T16-13-09Z
sudo docker pull motoserver/moto:latest

echo "[*] Precargando la base de vulnerabilidades de Trivy..."
trivy image --download-db-only || echo "[!] Trivy descargará su base en el Lab 5."

echo
echo "[+] Listo. Se debe cerrar sesión y volver a entrar (o ejecutar 'newgrp docker')"
echo "    para usar Docker sin sudo. Después: ./scripts/verificar-entorno.sh"
