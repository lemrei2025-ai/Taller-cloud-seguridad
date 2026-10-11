#!/usr/bin/env bash
# Comprueba que la máquina está lista para el taller. No modifica nada.
set -uo pipefail

ok=0; fallos=0
check() {  # check "descripción" comando...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  [OK]   %s\n' "$desc"; ok=$((ok+1))
  else
    printf '  [FALLA] %s\n' "$desc"; fallos=$((fallos+1))
  fi
}

echo "== Herramientas =="
for h in docker aws mc jq curl git nmap gitleaks trivy; do
  check "$h instalado" command -v "$h"
done
check "mc es el cliente S3 (no Midnight Commander)" bash -c "/usr/local/bin/mc --version 2>/dev/null | grep -qiE 'minio|silo'"
tv="$(trivy --version 2>/dev/null | awk '/^Version:/{print $2}')"
check "Trivy ${tv:-?} no es una versión comprometida (0.69.4-0.69.6)" bash -c "[[ -n '$tv' && ! '$tv' =~ ^0\.69\.[456]$ ]]"
check "Docker Compose disponible" bash -c 'docker compose version || docker-compose version'
check "Docker usable sin sudo" docker info

echo "== Recursos =="
ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
check "RAM >= 4 GB (disponible: ${ram_mb} MB)" test "$ram_mb" -ge 4000
disco_gb=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
check "Disco libre >= 5 GB (disponible: ${disco_gb} GB)" test "$disco_gb" -ge 5

echo "== Puertos libres (si el laboratorio NO está corriendo) =="
for p in 9000 9001 5000; do
  if ss -tln | grep -q ":$p "; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^nube-'; then
      printf '  [OK]   puerto %s (usado por el laboratorio)\n' "$p"; ok=$((ok+1))
    else
      printf '  [FALLA] puerto %s ocupado por otro programa\n' "$p"; fallos=$((fallos+1))
    fi
  else
    printf '  [OK]   puerto %s libre\n' "$p"; ok=$((ok+1))
  fi
done

echo
echo "Resultado: $ok correctos, $fallos con problemas."
[[ $fallos -eq 0 ]] && echo "La máquina Kali está lista para el taller." || echo "Consultar el Anexo B del documento (docs/00-preparacion.md)"
exit "$fallos"
