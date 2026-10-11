#!/usr/bin/env bash
# Crea el escenario del Lab 4:
#  1) Un usuario de servicio en MinIO ("la app web") con acceso a un bucket con datos de clientes.
#  2) Un repositorio git "de la app" donde un desarrollador subió esas credenciales
#     y luego las "borró" en otro commit (siguen en el historial).
# Requiere: laboratorio en marcha y 'source scripts/entorno.sh' cargado.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$DIR/app-vulnerable"

# Se usa el cliente de MinIO aunque Midnight Commander también se llame "mc".
mc() { if [[ -x /usr/local/bin/mc ]]; then /usr/local/bin/mc "$@"; else command mc "$@"; fi; }

mc alias list nube >/dev/null 2>&1 || { echo "[x] Primero se debe cargar: source scripts/entorno.sh" >&2; exit 1; }
[[ -d "$REPO" ]] && { echo "[!] El escenario ya existe en $REPO (se borra la carpeta para regenerarlo)."; exit 0; }

# Clave con formato de AWS (AKIA + 16 caracteres) para que los escáneres la reconozcan.
# (se lee un bloque fijo de /dev/urandom para no romper 'set -o pipefail' con SIGPIPE)
aleatorio() { head -c 4096 /dev/urandom | LC_ALL=C tr -dc "$1" | cut -c "1-$2"; }
ACCESS_KEY="AKIA$(aleatorio 'A-Z2-7' 16)"
SECRET_KEY="$(aleatorio 'A-Za-z0-9' 40)"

echo "[*] Creando bucket con datos ficticios de clientes..."
mc mb --ignore-existing nube/app-clientes >/dev/null
tmp="$(mktemp -d)"
cat >"$tmp/clientes.csv" <<'CSV'
id,nombre,correo,ciudad
1,Ana Pérez,ana.perez@ejemplo.test,Bogotá
2,Luis Gómez,luis.gomez@ejemplo.test,Medellín
3,Marta Ruiz,marta.ruiz@ejemplo.test,Cali
CSV
mc cp "$tmp/clientes.csv" nube/app-clientes/ >/dev/null
rm -rf "$tmp"

echo "[*] Creando la cuenta de servicio de la app..."
mc admin policy create nube app-web "$DIR/politicas/app-web.json" >/dev/null
mc admin user add nube "$ACCESS_KEY" "$SECRET_KEY" >/dev/null
mc admin policy attach nube app-web --user "$ACCESS_KEY" >/dev/null

echo "[*] Creando el repositorio de la app con el error del desarrollador..."
mkdir -p "$REPO"
cd "$REPO"
git init -q
git config user.name "Dev Apurado"
git config user.email "dev@ejemplo.test"

cat >app.py <<'PY'
import boto3
from config import S3_ENDPOINT, ACCESS_KEY, SECRET_KEY

s3 = boto3.client("s3", endpoint_url=S3_ENDPOINT,
                  aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY)
print(s3.list_objects_v2(Bucket="app-clientes"))
PY
cat >config.py <<PY
# TODO: mover a variables de entorno antes de producción
S3_ENDPOINT = "http://localhost:9000"
ACCESS_KEY = "$ACCESS_KEY"
SECRET_KEY = "$SECRET_KEY"
PY
git add . && git commit -qm "Primera versión de la app"

cat >config.py <<'PY'
import os
S3_ENDPOINT = os.environ["S3_ENDPOINT"]
ACCESS_KEY = os.environ["ACCESS_KEY"]
SECRET_KEY = os.environ["SECRET_KEY"]
PY
git add . && git commit -qm "Quitar credenciales del código (ya está seguro)"

echo "[+] Escenario listo en: $REPO"
echo "    El último commit ya no tiene credenciales... ¿o sí siguen en algún lado?"
