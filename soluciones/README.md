# Solucionario

> Se recomienda consultar este solucionario solo después de intentar cada laboratorio. Las respuestas pueden variar ligeramente según las versiones de las herramientas. Corresponde al Anexo H del [documento académico](../docs/Taller_Nube_Privada_Seguridad_APA.pdf).

## Laboratorio 1

1. Cada contenedor recibe una dirección en la red `nube-taller_nube`, normalmente en el rango `172.18.0.0/16`. Los contenedores se comunican por nombre de servicio (`minio`, `moto`) gracias al servicio de nombres interno de Docker.
2. La cabecera `Server: MinIO` revela el producto. Con la versión, un atacante puede buscar vulnerabilidades conocidas y ajustar su ataque.
3. Grupos de seguridad que limiten el origen, subredes privadas sin dirección pública, listas de control de acceso de red y acceso administrativo mediante una red privada virtual o un bastión, en lugar de publicar la consola.

## Laboratorio 2

1. Sí: con `public`, cualquier cliente anónimo puede leer, listar y escribir. `download` permite solo leer objetos; `upload`, solo escribir. Un contenedor con escritura anónima permite alterar contenidos, alojar software malicioso o generar costos de almacenamiento.
2. La traza muestra la dirección de origen, la operación de la API (`s3.GetObject`, `s3.ListObjectsV2`), el contenedor, el objeto, el código de respuesta y la ausencia de credencial.
3. La firma (`X-Amz-Signature`) es un código de autenticación calculado con la clave secreta sobre todos los parámetros, incluidos la fecha y la duración. Cualquier alteración invalida la firma.

## Laboratorio 3

1. El control total y permanente de la nube: crear usuarios, modificar políticas y borrar todos los datos, sin posibilidad de restringirlo con políticas. La buena práctica consiste en no crear claves de acceso para la cuenta raíz, protegerla con autenticación multifactor y reservarla para las tareas que la exigen.
2. `s3:ListBucket` es una operación sobre el contenedor y `s3:GetObject` es una operación sobre los objetos que contiene. Si se omite el recurso correspondiente, falla el listado o falla la lectura.

   Resultados de la identidad `analista`: listar informes ✅ · leer un informe ✅ · modificar un informe ❌ · leer la nómina ❌ · listar todos los contenedores ❌.
3. Toda solicitud está denegada por defecto. Un permiso la habilita, pero un rechazo explícito anula cualquier permiso, sin importar la política de origen. Por eso el robot no puede borrar copias. Sin embargo, mientras conserve `readwrite` **sí** puede leer `rrhh`, porque el rechazo solo cubre el borrado en `backups`.

## Laboratorio 4

1. En el primer commit ("Primera versión de la app"). Git conserva el historial completo y el segundo commit solo modifica la versión vigente. En un repositorio público, existen procesos automatizados que buscan claves con formato `AKIA...` pocos minutos después de su publicación.
2. La acción `secretsmanager:GetSecretValue` sobre el identificador exacto del secreto (`arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/app/base-datos-*`). Frente a un archivo `.env`, el gestor ofrece control de acceso por identidad, auditoría de cada lectura, cifrado y rotación automática.
3. Primero, `aws iam attach-user-policy --user-name diego-dev --policy-arn arn:aws:iam::aws:policy/AdministratorAccess`. Segundo, con `iam:CreateAccessKey` crea una clave nueva para conservar el acceso. La corrección consiste en retirar las acciones de IAM de su política o limitar `iam:CreateAccessKey` a su propio usuario (`"Resource": "arn:aws:iam::123456789012:user/${aws:username}"`), sin conceder nunca `AttachUserPolicy` ni `PutUserPolicy`.

## Laboratorio 5

1. Compilar el componente desde el código fuente y mantener una imagen propia, adoptar una bifurcación mantenida por la comunidad, migrar a otra solución compatible con S3 (Ceph RGW, Garage, SeaweedFS) o contratar la edición comercial. Mientras tanto, las vulnerabilidades sin corregir se acumulan en la imagen y en sus dependencias.
2. Son útiles la identidad (`accessKey`), la operación, el recurso, el código de respuesta 403 y la dirección de origen. En AWS, esta función la cumplen **AWS CloudTrail** (con eventos de datos de S3) junto con **Amazon GuardDuty** o las reglas del SIEM.

**Hallazgos y correcciones esperadas en la infraestructura como código (Parte B):**

| Recurso | Problema | Corrección |
|---|---|---|
| Bloqueo de acceso público | Los cuatro parámetros en `false` | Los cuatro parámetros en `true` |
| Contenedor S3 | Sin cifrado, versionado ni registro de accesos | `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_versioning`, `aws_s3_bucket_logging` |
| Grupo de seguridad | SSH desde `0.0.0.0/0` y salida sin restricción | SSH solo desde la red administrativa (o sustitución por SSM); restringir la salida |
| Instancia: metadatos | `http_tokens = "optional"` (IMDSv1) | `http_tokens = "required"` |
| Instancia: disco | `encrypted = false` | `encrypted = true` |
| Instancia: datos de usuario | Contraseña en texto plano | Lectura desde Secrets Manager al iniciar |
| Política IAM | Acción y recurso `*` | Acciones y recursos específicos |
