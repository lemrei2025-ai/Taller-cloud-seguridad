#!/usr/bin/env bash
# Instala todo lo necesario en Kali Linux. Se ejecuta UNA vez, antes del taller, con Internet.
# Funciona con un usuario normal (usa sudo) o directamente como root.
set -euo pipefail

SILO_IMG="pgsty/silo:RELEASE.2026-09-16T00-00-00Z"
MOTO_IMG="motoserver/moto:5.2.3"
MCLI_VER="20260916000000.0.0"
MCLI_TAG="RELEASE.2026-09-16T00-00-00Z"

if [[ $EUID -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

echo "[*] Actualizando índices de paquetes..."
$SUDO apt-get update

echo "[*] Instalando Docker, AWS CLI y herramientas de seguridad..."
$SUDO apt-get install -y docker.io docker-compose awscli jq curl git nmap gitleaks trivy

echo "[*] Habilitando Docker..."
$SUDO systemctl enable --now docker
if [[ $EUID -ne 0 ]]; then
  $SUDO usermod -aG docker "$USER"
fi

# Cliente S3/administración: mcli (bifurcación comunitaria del cliente mc de MinIO).
# Se publica como "mc" en /usr/local/bin para que los comandos de las guías funcionen
# y para no confundirlo con Midnight Commander, que también se llama "mc".
if ! /usr/local/bin/mc --version 2>/dev/null | grep -qiE 'minio|silo'; then
  echo "[*] Instalando el cliente mcli (compatible con mc de MinIO)..."
  arq="$(dpkg --print-architecture)"   # amd64 o arm64
  tmp="$(mktemp -d)"
  url="https://github.com/pgsty/mc/releases/download/${MCLI_TAG}/mcli_${MCLI_VER}_${arq}.deb"
  if curl -fL "$url" -o "$tmp/mcli.deb"; then
    $SUDO apt-get install -y "$tmp/mcli.deb"
    $SUDO ln -sf /usr/local/bin/mcli /usr/local/bin/mc
  else
    echo "[!] No se pudo descargar mcli desde $url" >&2
  fi
  rm -rf "$tmp"
fi

# Trivy sufrió un ataque de cadena de suministro en marzo de 2026 (GHSA-69fq-xp46-6x23):
# las versiones 0.69.4, 0.69.5 y 0.69.6 eran maliciosas.
tv="$(trivy --version 2>/dev/null | awk '/^Version:/{print $2}')"
case "$tv" in
  0.69.4|0.69.5|0.69.6)
    echo "[x] Trivy $tv es una versión COMPROMETIDA. Se debe desinstalar y rotar credenciales." >&2 ;;
  "") echo "[!] Trivy no quedó instalado." >&2 ;;
  *)  echo "[+] Trivy $tv (no está entre las versiones comprometidas)." ;;
esac

echo "[*] Descargando imágenes del laboratorio (para trabajar sin Internet el día del taller)..."
$SUDO docker pull "$SILO_IMG"
$SUDO docker pull "$MOTO_IMG"

echo "[*] Precargando la base de vulnerabilidades de Trivy..."
trivy image --download-db-only || echo "[!] Trivy descargará su base en el Lab 5."

echo
if [[ $EUID -ne 0 ]]; then
  echo "[+] Listo. Se debe cerrar sesión y volver a entrar (o ejecutar 'newgrp docker')"
  echo "    para usar Docker sin sudo. Después: ./scripts/verificar-entorno.sh"
else
  echo "[+] Listo. Siguiente paso: ./scripts/verificar-entorno.sh"
fi
