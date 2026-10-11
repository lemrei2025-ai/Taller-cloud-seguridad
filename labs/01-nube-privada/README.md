# Laboratorio 1 · Despliegue de la nube privada y superficie de ataque

⏱️ **30 minutos** · 🎯 **Objetivo:** desplegar la nube privada, reconocer sus componentes y analizarla desde la perspectiva de un atacante.

**Amenaza:** configuración errónea e interfaces expuestas (CSA, 2024).
**Controles ISO/IEC 27002:2022:** 8.20 Seguridad de redes · 8.9 Gestión de la configuración.

## Conceptos clave

- **IaaS, PaaS y SaaS:** indican qué parte administra el proveedor y qué parte el cliente. En el taller, el participante actúa a la vez como proveedor y como cliente, por lo que es responsable de todas las capas.
- **Responsabilidad compartida:** el proveedor asegura la infraestructura física y la virtualización; el cliente asegura sus datos, identidades y configuraciones. La mayoría de las brechas en la nube se originan en el ámbito del cliente.
- **Plano de control y plano de datos:** las API de administración (crear usuarios, cambiar políticas) frente a las API que mueven datos (subir y descargar archivos). Proteger el plano de control es prioritario, porque quien lo controla domina todo el entorno.

## Paso 1 · Despliegue de los servicios

```bash
cd ~/taller-cloud-seguridad
./scripts/lab.sh up
./scripts/lab.sh status
source scripts/entorno.sh
```

Se accede a la consola de MinIO en <http://localhost:9001> con los valores `MINIO_ROOT_USER` y `MINIO_ROOT_PASSWORD` del archivo `.env`. El panel de Moto está disponible en <http://localhost:5000/moto-api/>.

## Paso 2 · Reconocimiento de los componentes

```bash
docker compose ps                         # o docker-compose ps
docker network inspect nube-taller_nube | jq '.[0].Containers'
mc admin info nube
awsm sts get-caller-identity
```

❓ **Pregunta 1.** ¿Qué dirección IP interna tiene cada contenedor y cómo se comunican entre sí?

## Paso 3 · Reconocimiento desde la perspectiva del atacante

```bash
sudo ss -tlnp | grep -E ':(9000|9001|5000)'
nmap -sV -p 9000,9001,5000 127.0.0.1
curl -i http://localhost:9000/
```

Se observa que los puertos escuchan solo en `127.0.0.1`, como lo define `docker-compose.yml`:

```yaml
ports:
  - "127.0.0.1:9000:9000"
```

❓ **Pregunta 2.** ¿Qué cabecera HTTP revela que el servicio es MinIO y qué información aporta a un atacante?

## Paso 4 · Simulación de una exposición accidental

1. En `docker-compose.yml` se reemplaza `"127.0.0.1:9001:9001"` por `"9001:9001"`.
2. Se aplica el cambio con `./scripts/lab.sh up`.
3. Se comprueba la exposición:

   ```bash
   ip -4 addr show | grep inet            # dirección IP de red del equipo
   sudo ss -tlnp | grep 9001              # ahora escucha en 0.0.0.0
   nmap -p 9001 <IP_DE_RED>
   ```

4. Si otros participantes comparten la red, uno de ellos escanea la dirección del equipo con `nmap -p 9001 <IP>`.

⚠️ Docker inserta sus propias reglas de filtrado de paquetes. Según su documentación, los puertos publicados se enrutan antes de que se apliquen las reglas de `ufw`. Por eso, aunque el cortafuegos del equipo esté activo, el puerto puede quedar accesible. Este comportamiento ha causado exposiciones reales en servidores en la nube.

5. Se revierte el cambio (de nuevo `127.0.0.1:9001:9001`) y se ejecuta `./scripts/lab.sh up`.

❓ **Pregunta 3.** ¿Qué controles de un proveedor público evitarían esta exposición?

## ✅ Conclusiones del laboratorio

- La seguridad en la nube comienza por definir qué se expone y a quién.
- Cada servicio publicado amplía la superficie de ataque. Por defecto, los servicios se publican solo en `127.0.0.1` o detrás de una red privada.
- Los *banners* y las cabeceras facilitan el reconocimiento al atacante.

➡️ Siguiente: [Laboratorio 2 · Almacenamiento mal configurado](../02-almacenamiento/)
