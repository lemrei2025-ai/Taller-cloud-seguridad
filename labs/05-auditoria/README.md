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
trivy --version                                    # nunca 0.69.4, 0.69.5 ni 0.69.6
trivy image --severity HIGH,CRITICAL pgsty/silo:RELEASE.2026-09-16T00-00-00Z
trivy image --severity HIGH,CRITICAL --format json -o reportes/silo.json \
  pgsty/silo:RELEASE.2026-09-16T00-00-00Z
jq '[.Results[]?.Vulnerabilities // [] | .[]] | group_by(.Severity) | map({(.[0].Severity): length}) | add' \
  reportes/silo.json
```

El propio taller ilustra tres incidentes reales de cadena de suministro de 2025–2026:

| Componente | Qué ocurrió | Impacto |
|---|---|---|
| MinIO | Dejó de publicar versiones comunitarias (octubre de 2025) y eliminó sus imágenes de Docker Hub (septiembre de 2026) | Los despliegues fallan con `pull access denied`; las imágenes antiguas no reciben parches |
| LocalStack | Pasó a exigir cuenta y token para iniciar su contenedor (marzo de 2026) | Los entornos de pruebas sin token dejan de funcionar |
| Trivy | Versiones 0.69.4 a 0.69.6 publicadas con código malicioso (marzo de 2026) | Robo de credenciales de los equipos y pipelines que las ejecutaron |

❓ **Pregunta 1.** ¿Qué controles reducen cada uno de estos riesgos? (Pista: fijar versiones o *digests*, réplica propia del registro de imágenes, verificación de firmas, alternativas evaluadas de antemano).

## Parte B · Infraestructura como código insegura (12 min)

El archivo `terraform/main.tf` describe una pequeña infraestructura en AWS con errores deliberados. **No se despliega**: solo se analiza.

```bash
cat terraform/main.tf
trivy config terraform/
trivy config --severity HIGH,CRITICAL terraform/ -f table
```

Con Trivy 0.69.3, el análisis reporta **13 hallazgos** (2 críticos, 8 altos, 1 medio y 2 bajos). Se completa la tabla:

| Recurso | Problema | Riesgo | Corrección |
|---|---|---|---|
| `aws_s3_bucket_public_access_block` | | | |
| `aws_security_group.servidor_web` | | | |
| `aws_instance.web` (metadatos) | | | |
| `aws_instance.web` (disco) | | | |
| `aws_iam_policy.app` | | | |

❓ **Pregunta 2.** La plantilla contiene una política IAM con `"Action": "*"` y `"Resource": "*"`. ¿Aparece entre los hallazgos de Trivy? ¿Qué conclusión se obtiene sobre depender de una sola herramienta? (Comparar con el auditor del Laboratorio 4.)

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

❓ **Pregunta 3.** ¿Qué campos de la traza sustentarían una alerta de "usuario que intenta leer datos de recursos humanos"? ¿Qué servicios cumplen esa función en AWS?

## ✅ Conclusiones del laboratorio

- Las **imágenes** y la **infraestructura como código** se escanean en el proceso de integración, antes del despliegue.
- Fijar versiones de las imágenes es necesario, pero se debe vigilar que sigan recibiendo actualizaciones.
- Sin registros no hay investigación posible: la auditoría se activa desde el primer día.

🏁 El taller concluye con la [lista de verificación](../../recursos/checklist-seguridad.md) y el reto final de la [guía del facilitador](../../docs/guia-facilitador.md).
