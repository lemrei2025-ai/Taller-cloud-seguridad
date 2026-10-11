# shellcheck shell=bash
# Cargar en cada terminal nueva:   source scripts/entorno.sh
# (no se ejecuta, se "sourcea": define variables y alias en la shell actual)

_RAIZ_TALLER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$_RAIZ_TALLER/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$_RAIZ_TALLER/.env"
  set +a
else
  echo "[x] Falta .env. Se debe ejecutar primero: ./scripts/lab.sh up" >&2
  return 1 2>/dev/null || exit 1
fi

# AWS CLI apuntando a Moto (la "AWS" local del laboratorio). Nunca toca una cuenta real.
export AWS_PAGER=""
alias awsm='aws --endpoint-url http://localhost:5000'

# "mc" también es el nombre de Midnight Commander: se prefiere el binario de MinIO.
if [[ -x /usr/local/bin/mc ]]; then
  alias mc=/usr/local/bin/mc
  _MC=/usr/local/bin/mc
else
  _MC=mc
fi

# Alias "nube" del cliente (mc/mcli) con la cuenta root (solo para administrar)
if "$_MC" --version 2>/dev/null | grep -qiE 'minio|silo'; then
  "$_MC" alias set nube http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null \
    && echo "[+] Alias 'nube' de mc configurado (cuenta root)."
else
  echo "[!] El cliente 'mc' (mcli) no está instalado. Se debe ejecutar: ./scripts/instalar-herramientas.sh" >&2
fi
unset _MC

echo "[+] Entorno cargado: 'awsm' para AWS emulado y 'mc ... nube/' para el almacenamiento S3."
