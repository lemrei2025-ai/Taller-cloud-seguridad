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

El script instala con `apt` los paquetes `docker.io`, `docker-compose`, `awscli`, `jq`, `curl`, `git`, `nmap`, `gitleaks` y `trivy`. Además descarga el cliente `mc` de MinIO, las imágenes Docker del laboratorio y la base de vulnerabilidades de Trivy.

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

# Cliente de MinIO
curl -fL https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
sudo install -m 0755 mc /usr/local/bin/mc && rm mc
mc --version
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
| `permission denied ... docker.sock` | No se recargó el grupo `docker` | Ejecutar `newgrp docker` o cerrar la sesión |
| `port is already allocated` | Otro programa usa el puerto 9000, 9001 o 5000 | Identificarlo con `sudo ss -tlnp` y detenerlo |
| `mc: command not found` | Falló la descarga de `mc` | Instalarlo manualmente (sección 3) o usar `docker exec nube-minio mc ...` |
| `mc` abre un gestor de archivos | Midnight Commander comparte el nombre `mc` | Usar `/usr/local/bin/mc`; los scripts ya lo priorizan |
| Paquete `gitleaks` o `trivy` no encontrado | Índices de paquetes desactualizados | `sudo apt update && sudo apt full-upgrade` |
| Moto responde con error 500 en IAM | Imagen antigua en caché | `docker pull motoserver/moto:latest && ./scripts/lab.sh reset` |
| MinIO no inicia | Contraseña raíz de menos de 8 caracteres en `.env` | Usar una contraseña de 8 caracteres o más |
