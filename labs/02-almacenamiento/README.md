# Laboratorio 2 · Almacenamiento mal configurado

⏱️ **45 minutos** · 🎯 **Objetivo:** reproducir la exposición de datos por un contenedor de almacenamiento público, enumerarlo sin credenciales y corregirlo.

**Amenaza:** divulgación accidental de datos y compartición de recursos sin autenticación (CSA, 2024).
**Controles ISO/IEC 27002:2022:** 5.15 Control de acceso · 8.3 Restricción del acceso a la información · 8.12 Prevención de fuga de datos · 8.13 Copias de respaldo.

## Contexto

Los contenedores de almacenamiento de objetos (S3 y compatibles) son privados por defecto. Sin embargo, un solo cambio de configuración basta para que cualquier persona en Internet pueda listarlos y descargar su contenido. Numerosas filtraciones masivas de datos personales se originaron así, sin necesidad de explotar ninguna vulnerabilidad.

```bash
source scripts/entorno.sh   # en cada terminal nueva
```

## Parte A · El administrador comete el error (10 min)

```bash
# 1. Creación de dos contenedores
mc mb nube/marketing
mc mb nube/rrhh

# 2. Carga de contenido de prueba (datos ficticios)
echo "Campaña Navidad 2026 - borrador" > campana.txt
printf 'cedula,nombre,salario\n1010,Ana Pérez,8500000\n1020,Luis Gómez,7200000\n' > nomina.csv
mc cp campana.txt nube/marketing/
mc cp nomina.csv  nube/rrhh/

# 3. "Para que el equipo de diseño vea los archivos sin cuenta"...
mc anonymous set public nube/marketing
mc anonymous set public nube/rrhh       # ← el error: la misma política aplicada a todos
```

## Parte B · Enumeración anónima (15 min)

En esta parte, el participante actúa como atacante **sin usuario ni contraseña**. Solo utiliza `curl`.

```bash
# Prueba de nombres de contenedores habituales
for b in backup backups datos rrhh nomina marketing finanzas logs dev prod; do
  codigo=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:9000/$b/")
  echo "$b -> HTTP $codigo"
done
```

En Amazon S3, el patrón clásico de respuestas es el siguiente:

| Código | Significado para el atacante |
|---|---|
| `404` | El contenedor no existe |
| `403` | **Existe**, pero no hay permiso (su existencia queda confirmada) |
| `200` | Existe **y su contenido puede listarse** |

Para comprobar si MinIO distingue entre un contenedor inexistente y uno privado, se crea un contenedor privado (`mc mb nube/finanzas`) y se repite el bucle. No distinguir ambos casos es una buena decisión de diseño, porque no entrega información al atacante.

```bash
# Listado del contenido de un contenedor abierto (respuesta XML)
curl -s http://localhost:9000/rrhh/ | grep -oP '(?<=<Key>)[^<]+'

# Descarga del archivo
curl -s http://localhost:9000/rrhh/nomina.csv
```

❓ **Pregunta 1.** Se intenta ahora **escribir** de forma anónima:
`curl -X PUT --data 'alterado' http://localhost:9000/marketing/defacement.html`
¿Funciona? ¿Qué diferencia existe entre las políticas anónimas `download`, `upload` y `public`?

❓ **Pregunta 2.** Se ejecuta `mc admin trace nube` en otra terminal y se repite la petición. ¿Qué información obtiene el defensor sobre la petición anónima?

## Parte C · Corrección (15 min)

### C.1 · Retiro del acceso anónimo

```bash
mc anonymous get nube/rrhh
mc anonymous set none nube/rrhh
mc anonymous set none nube/marketing
mc anonymous list nube/marketing          # debe quedar vacío
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:9000/rrhh/nomina.csv   # ahora 403
```

### C.2 · Compartición correcta: URL prefirmada con caducidad

El equipo de diseño necesitaba acceder a **un** archivo, no al contenedor completo:

```bash
mc share download --expire 2m nube/marketing/campana.txt
```

Se copia la URL que aparece en *Share:*, se abre con `curl` y se repite el intento pasados dos minutos.

❓ **Pregunta 3.** ¿Por qué no es posible modificar la fecha de caducidad incluida en los parámetros de la URL (`X-Amz-Expires`, `X-Amz-Signature`)?

### C.3 · Defensa contra el borrado y el *ransomware*: versionado

```bash
mc version enable nube/rrhh
echo "versión corrupta por ransomware" | mc pipe nube/rrhh/nomina.csv
mc ls --versions nube/rrhh/nomina.csv
mc cat --vid <ID_DE_VERSION_ANTERIOR> nube/rrhh/nomina.csv   # el original sigue disponible
```

> Si la instalación indica que el versionado no está disponible, se registra la observación. En producción, MinIO se despliega con varios discos (*erasure coding*), configuración en la que el versionado sí está disponible.

## ✅ Conclusiones del laboratorio

- El acceso público rara vez es la necesidad real del negocio; las **URL prefirmadas** con caducidad la resuelven.
- Un código `403` puede confirmar que un recurso existe; los nombres de los contenedores no deben ser predecibles.
- El **versionado** (y, en AWS, el bloqueo de objetos) es la defensa más simple contra el borrado malicioso.
- En AWS, el **bloqueo de acceso público** activado a nivel de cuenta impide este error de raíz.

➡️ Siguiente: [Laboratorio 3 · Identidad y mínimo privilegio](../03-iam-minio/)
