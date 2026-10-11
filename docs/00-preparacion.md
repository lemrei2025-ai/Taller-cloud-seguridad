# 00 · Preparación del entorno

La preparación se realiza **antes del taller** y requiere entre 20 y 30 minutos con conexión a Internet. El día del taller no se necesita conexión. Este procedimiento corresponde al Anexo B del [documento académico](Taller_Nube_Privada_Seguridad_APA.pdf).

## 1. Requisitos del equipo

| Recurso | Mínimo | Recomendado |
|---|---|---|
| Sistema operativo | Kali Linux 2025.x (rolling) | Kali Linux actualizada |
| Memoria RAM | 4 GB | 8 GB |
| Disco libre | 5 GB | 10 GB |
| Procesador | 2 núcleos | 4 núcleos |

En una **máquina virtual** (VirtualBox o VMware) se asignan al menos 4 GB de RAM y 2 procesadores. En **WSL2**, Docker funciona igual si se habilita systemd (`/etc/wsl.conf` → `[boot] systemd=true`).

## 2. Instalación automática

```bash
git clone https://github.com/<usuario>/taller-cloud-seguridad.git
cd taller-cloud-seguridad
chmod +x scripts/*.sh labs/*/*.sh
./scripts/instalar-herramientas.sh
```

El script instala con `apt` los paquetes `docker.io`, `docker-compose`, `awscli`, `jq`, `curl`, `git`, `nmap`, `gitleaks` y `trivy`. Además instala el cliente `mcli` (compatible con `mc` de MinIO) como `/usr/local/bin/mc`, descarga las imágenes Docker del laboratorio y la base de vulnerabilidades de Trivy, y comprueba que Trivy no sea una versión comprometida. El script funciona con un usuario normal o como `root`.

Al terminar se cierra la sesión y se vuelve a iniciar (o se ejecuta `newgrp docker`). Después se verifica el entorno:

```bash
./scripts/verificar-entorno.sh
```

## 3. Instalación manual (alternativa)

```bash
sudo apt update
sudo apt install -y docker.io docker-compose awscli jq curl git nmap gitleaks trivy
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

# Cliente S3 (mcli, bifurcación comunitaria de mc). En ARM se cambia amd64 por arm64.
curl -fLO https://github.com/pgsty/mc/releases/download/RELEASE.2026-09-16T00-00-00Z/mcli_20260916000000.0.0_amd64.deb
sudo apt install -y ./mcli_20260916000000.0.0_amd64.deb
sudo ln -sf /usr/local/bin/mcli /usr/local/bin/mc
mc --version

# Imágenes del laboratorio
docker pull pgsty/silo:RELEASE.2026-09-16T00-00-00Z
docker pull motoserver/moto:5.2.3
```

> **Nota de seguridad.** La pertenencia al grupo `docker` equivale a privilegios de administrador sobre el equipo. Es aceptable en un laboratorio, pero en servidores de producción se prefiere ejecutar Docker sin privilegios (modo *rootless*). Esta es la primera decisión de seguridad que se discute en el taller.

## 4. Prueba de funcionamiento

```bash
./scripts/lab.sh up
source scripts/entorno.sh
mc admin info nube                       # debe mostrar un servidor en línea
awsm sts get-caller-identity             # debe mostrar la cuenta 123456789012
./scripts/lab.sh down
```

## 5. Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `source scripts/entorno.sh` responde «Falta .env» aunque el archivo existe | Versión antigua de `entorno.sh`, que solo funcionaba en bash (Kali usa zsh por defecto) | Actualizar el repositorio; como solución inmediata, ejecutar `bash` y luego `source scripts/entorno.sh` |
| `permission denied ... docker.sock` | No se recargó el grupo `docker` | Ejecutar `newgrp docker` o cerrar la sesión |
| `port is already allocated` | Otro programa usa el puerto 9000, 9001 o 5000 | Identificarlo con `sudo ss -tlnp` y detenerlo |
| `pull access denied for minio/minio` | MinIO eliminó sus imágenes de Docker Hub en septiembre de 2026 | Usar la versión actual del repositorio, que emplea `pgsty/silo` |
| `mc: command not found` | Falló la descarga de `mcli` | Instalarlo manualmente (sección 3) o usar `docker exec nube-minio mc ...` |
| Trivy aparece como versión comprometida | Se instaló la 0.69.4, 0.69.5 o 0.69.6 | Desinstalarla, instalar una versión segura y rotar las credenciales del equipo |
| `mc` abre un gestor de archivos | Midnight Commander comparte el nombre `mc` | Usar `/usr/local/bin/mc`; los scripts ya lo priorizan |
| Paquete `gitleaks` o `trivy` no encontrado | Índices de paquetes desactualizados | `sudo apt update && sudo apt full-upgrade` |
| Moto responde con error 500 en IAM | Imagen antigua en caché | `docker pull motoserver/moto:latest && ./scripts/lab.sh reset` |
| MinIO no inicia | Contraseña raíz de menos de 8 caracteres en `.env` | Usar una contraseña de 8 caracteres o más |
| Faltan `.env.example` o `.gitignore` | Los archivos que empiezan por `.` son ocultos y se pierden al copiar con un gestor de archivos o al subir por la web de GitHub | Clonar con `git clone` o copiar con `cp -a`; `lab.sh` genera `.env` igualmente |
