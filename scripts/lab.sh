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

if [[ ! -f .env ]]; then
  echo "[!] No existe .env; se crea desde .env.example. La contraseña debe cambiarse antes del taller."
  cp .env.example .env
fi

esperar_minio() {
  echo -n "[*] Esperando a MinIO"
  for _ in $(seq 1 30); do
    if curl -fsS http://localhost:9000/minio/health/live >/dev/null 2>&1; then
      echo " listo."
      return 0
    fi
    echo -n "."
    sleep 2
  done
  echo
  echo "[x] MinIO no respondió en 60 s. Revisar: ./scripts/lab.sh logs" >&2
  return 1
}

case "${1:-}" in
  up)
    "${COMPOSE[@]}" up -d
    esperar_minio
    echo "[+] Nube privada en marcha:"
    echo "    API S3 (MinIO) : http://localhost:9000"
    echo "    Consola MinIO  : http://localhost:9001"
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
