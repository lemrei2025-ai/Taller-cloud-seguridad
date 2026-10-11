#!/usr/bin/env bash
# Control del laboratorio: ./scripts/lab.sh {up|down|reset|status|logs}
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# Kali puede traer "docker compose" (plugin) o "docker-compose" (binario). Se usa el que exista.
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "[x] No se encontró Docker Compose. Se debe ejecutar: ./scripts/instalar-herramientas.sh" >&2
  exit 1
fi

# Si no existe .env, se genera con una contraseña aleatoria (no depende de .env.example,
# que puede perderse al copiar el repositorio porque los archivos que empiezan por "." son ocultos).
if [[ ! -f .env ]]; then
  clave="Taller-$(head -c 4096 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c 1-16)"
  cat >.env <<EOF
# Generado automáticamente por scripts/lab.sh. Nunca debe subirse a GitHub.
MINIO_ROOT_USER=admin-taller
MINIO_ROOT_PASSWORD=$clave
AWS_ACCESS_KEY_ID=testing
AWS_SECRET_ACCESS_KEY=testing
AWS_DEFAULT_REGION=us-east-1
EOF
  chmod 600 .env
  echo "[+] Se creó .env con una contraseña aleatoria para el almacenamiento (consultar con: cat .env)."
fi
[[ -f .gitignore ]] || echo "[!] Aviso (no es un error): falta .gitignore, así que .env podría subirse a GitHub. Ver docs/00-preparacion.md." >&2

esperar_minio() {
  echo -n "[*] Esperando al almacenamiento S3"
  for _ in $(seq 1 30); do
    if curl -fsS http://localhost:9000/minio/health/live >/dev/null 2>&1; then
      echo " listo."
      return 0
    fi
    echo -n "."
    sleep 2
  done
  echo
  echo "[x] El almacenamiento no respondió en 60 s. Revisar: ./scripts/lab.sh logs" >&2
  return 1
}

case "${1:-}" in
  up)
    "${COMPOSE[@]}" up -d
    esperar_minio
    echo "[+] Nube privada en marcha:"
    echo "    API S3 (Silo)  : http://localhost:9000"
    echo "    Consola web    : http://localhost:9001"
    echo "    APIs AWS (Moto): http://localhost:5000  (panel: http://localhost:5000/moto-api/)"
    echo "    Siguiente paso : source scripts/entorno.sh"
    ;;
  down)
    "${COMPOSE[@]}" down
    ;;
  reset)
    read -r -p "Esto borra TODOS los datos del laboratorio. ¿Continuar? [s/N] " r
    [[ "$r" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }
    "${COMPOSE[@]}" down -v
    rm -rf labs/04-secretos/app-vulnerable labs/05-auditoria/reportes
    "${COMPOSE[@]}" up -d
    esperar_minio
    echo "[+] Laboratorio reiniciado desde cero."
    ;;
  status)
    "${COMPOSE[@]}" ps
    ;;
  logs)
    "${COMPOSE[@]}" logs --tail=50 -f
    ;;
  *)
    echo "Uso: $0 {up|down|reset|status|logs}"
    exit 1
    ;;
esac
