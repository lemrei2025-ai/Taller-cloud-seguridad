# Laboratorio 5 · Auditoría y aseguramiento

⏱️ **30 minutos** · 🎯 **Objetivo:** auditar la nube como lo haría un equipo de seguridad: imágenes de contenedor, infraestructura como código y registros de actividad.

**Amenaza:** vulnerabilidades del sistema, recursos inseguros de terceros y visibilidad limitada (CSA, 2024).
**Controles ISO/IEC 27002:2022:** 8.8 Gestión de vulnerabilidades técnicas · 8.9 Gestión de la configuración · 8.15 Registro · 8.16 Seguimiento de actividades.

```bash
cd ~/taller-cloud-seguridad/labs/05-auditoria
mkdir -p reportes
```

## Parte A · Seguridad de la imagen en ejecución (10 min)

```bash
trivy image --severity HIGH,CRITICAL minio/minio:RELEASE.2025-09-07T16-13-09Z
trivy image --severity HIGH,CRITICAL --format json -o reportes/minio.json \
  minio/minio:RELEASE.2025-09-07T16-13-09Z
jq '[.Results[].Vulnerabilities // [] | .[]] | group_by(.Severity) | map({(.[0].Severity): length}) | add' \
  reportes/minio.json
```

❓ **Pregunta 1.** MinIO dejó de publicar imágenes comunitarias en octubre de 2025. ¿Qué opciones tiene una organización que depende de este componente? ¿Qué riesgo de **cadena de suministro** introduce depender de una imagen que no recibe actualizaciones?

## Parte B · Infraestructura como código insegura (12 min)

El archivo `terraform/main.tf` describe una pequeña infraestructura en AWS con errores deliberados. **No se despliega**: solo se analiza.

```bash
cat terraform/main.tf
trivy config terraform/
trivy config --severity HIGH,CRITICAL terraform/ -f table
```

Se completa la tabla con los hallazgos de Trivy:

| Recurso | Problema | Riesgo | Corrección |
|---|---|---|---|
| `aws_s3_bucket_public_access_block` | | | |
| `aws_security_group.servidor_web` | | | |
| `aws_instance.web` (metadatos) | | | |
| `aws_instance.web` (disco) | | | |
| `aws_iam_policy.app` | | | |

✏️ **Ejercicio:** se copia el archivo a `terraform/main-corregido.tf`, se corrigen los hallazgos y se repite `trivy config terraform/` hasta que solo queden hallazgos justificables.

> **Gravedad de IMDSv1.** Si una aplicación web presenta una falla SSRF, el atacante puede forzarla a consultar `http://169.254.169.254/` y obtener las credenciales temporales del rol de la instancia. IMDSv2 (`http_tokens = "required"`) exige un token de sesión previo y bloquea ese abuso.

## Parte C · Registro de actividad (8 min)

En una terminal se deja en ejecución la traza de la API de MinIO:

```bash
mc admin trace -v nube 2>&1 | tee reportes/traza.log
```

En otra terminal se genera actividad permitida, denegada y anónima:

```bash
source ~/taller-cloud-seguridad/scripts/entorno.sh
mc cat analista/informes/q3.txt
mc cat analista/rrhh/nomina.csv          # denegado
curl -s http://localhost:9000/rrhh/      # anónimo
```

Se detiene la traza con `Ctrl+C` y se analiza:

```bash
grep -cE 'AccessDenied|403' reportes/traza.log
```

❓ **Pregunta 2.** ¿Qué campos de la traza sustentarían una alerta de "usuario que intenta leer datos de recursos humanos"? ¿Qué servicios cumplen esa función en AWS?

## ✅ Conclusiones del laboratorio

- Las **imágenes** y la **infraestructura como código** se escanean en el proceso de integración, antes del despliegue.
- Fijar versiones de las imágenes es necesario, pero se debe vigilar que sigan recibiendo actualizaciones.
- Sin registros no hay investigación posible: la auditoría se activa desde el primer día.

🏁 El taller concluye con la [lista de verificación](../../recursos/checklist-seguridad.md) y el reto final de la [guía del facilitador](../../docs/guia-facilitador.md).
