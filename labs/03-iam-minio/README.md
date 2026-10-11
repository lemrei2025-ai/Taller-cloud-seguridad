# Laboratorio 3 · Identidad y mínimo privilegio

⏱️ **40 minutos** · 🎯 **Objetivo:** sustituir el uso de la cuenta raíz por identidades con permisos mínimos y verificar que las políticas se aplican efectivamente.

**Amenaza:** gestión de identidades y accesos (CSA, 2024).
**Controles:** ISO/IEC 27002:2022 5.15, 5.18 y 8.2 · NIST SP 800-53 AC-6 (mínimo privilegio).

> En la nube, **la identidad es el nuevo perímetro**. No existe un cortafuegos que separe el interior del exterior: cada llamada a la API se autoriza según quién la realiza y qué políticas tiene asignadas.

```bash
cd ~/taller-cloud-seguridad/labs/03-iam-minio
source ../../scripts/entorno.sh
mc mb --ignore-existing nube/informes nube/backups
echo "Informe trimestral Q3" | mc pipe nube/informes/q3.txt
```

## Parte A · El problema de la cuenta raíz (5 min)

Hasta este punto, todas las operaciones se realizaron con el alias `nube`, que utiliza las credenciales **raíz**. Esa identidad no puede restringirse con políticas.

```bash
mc admin user info nube "$MINIO_ROOT_USER"    # responde que el usuario no existe: la raíz no es un usuario IAM
mc admin policy list nube                     # políticas predefinidas de MinIO
mc admin policy info nube readwrite
```

❓ **Pregunta 1.** Si una aplicación usa las credenciales raíz y estas se filtran, ¿qué puede hacer el atacante? ¿Qué buena práctica recomienda AWS para la cuenta raíz?

## Parte B · El atajo peligroso (10 min)

Un practicante necesita consultar los informes. Por prisa, se le asignan permisos totales:

```bash
cat politicas/demasiado-permisiva.json
mc admin policy create nube demasiado-permisiva politicas/demasiado-permisiva.json
mc admin user add nube practicante 'Practicante-2026'
mc admin policy attach nube demasiado-permisiva --user practicante

# Sesión con la identidad del practicante
mc alias set practicante http://localhost:9000 practicante 'Practicante-2026'
mc ls practicante/
mc cat practicante/rrhh/nomina.csv             # puede leer la nómina
# mc rb --force practicante/backups            # también podría borrar las copias (no se ejecuta)
```

## Parte C · Mínimo privilegio (15 min)

### C.1 · Política a la medida

```bash
cat politicas/analista-lectura-informes.json
mc admin policy create nube analista-informes politicas/analista-lectura-informes.json
mc admin user add nube analista 'Analista-2026!'
mc admin policy attach nube analista-informes --user analista
mc alias set analista http://localhost:9000 analista 'Analista-2026!'
```

Se completa la tabla ejecutando cada comando:

| Prueba | Comando | ¿Permitido? |
|---|---|---|
| Listar informes | `mc ls analista/informes` | |
| Leer un informe | `mc cat analista/informes/q3.txt` | |
| Modificar un informe | `echo x \| mc pipe analista/informes/q3.txt` | |
| Leer la nómina | `mc cat analista/rrhh/nomina.csv` | |
| Listar todos los contenedores | `mc ls analista/` | |

> Observación: en el último caso, el servidor no devuelve un error. Muestra **solo** los contenedores a los que la identidad tiene acceso.

❓ **Pregunta 2.** ¿Por qué `s3:ListBucket` utiliza el recurso `arn:aws:s3:::informes` y `s3:GetObject` utiliza `arn:aws:s3:::informes/*`?

### C.2 · El rechazo explícito prevalece

La cuenta de respaldos debe escribir copias, pero **nunca** borrarlas, aunque otro administrador le asigne permisos de más por error.

```bash
cat politicas/backup-sin-borrado.json
mc admin policy create nube backup-sin-borrado politicas/backup-sin-borrado.json
mc admin user add nube robot-backup 'RobotBackup-2026'
mc admin policy attach nube backup-sin-borrado --user robot-backup
mc admin policy attach nube readwrite --user robot-backup     # el "error" de otro administrador

mc alias set robot http://localhost:9000 robot-backup 'RobotBackup-2026'
echo "copia $(date +%F)" | mc pipe robot/backups/copia.txt     # ¿se permite?
mc rm robot/backups/copia.txt                                  # ¿se permite?
mc cat robot/rrhh/nomina.csv                                   # ¿se permite? ¿por qué?
```

❓ **Pregunta 3.** El robot tiene `readwrite` (todas las acciones de S3) y un rechazo explícito sobre el borrado. ¿Qué prevalece? Se formula la regla de evaluación de políticas con palabras propias.

## Parte D · Respuesta a incidentes: revocación del acceso (10 min)

Se supone que las credenciales del practicante se filtraron. El orden importa: el servidor no permite modificar las políticas de un usuario ya deshabilitado, por lo que primero se retiran los permisos y después se deshabilita la cuenta.

```bash
mc admin policy detach nube demasiado-permisiva --user practicante   # 1. retirar permisos
mc admin user disable nube practicante                              # 2. deshabilitar la cuenta
mc ls practicante/                                   # debe fallar: "Your account is disabled"
mc admin policy detach nube readwrite --user robot-backup     # se corrige el error anterior
mc admin user list nube
```

🔍 **Reto:** se ejecuta `mc admin trace -v nube` en otra terminal mientras el practicante (antes de deshabilitarlo) lee la nómina. ¿Qué datos registraría un SIEM para investigar el incidente?

## ✅ Conclusiones del laboratorio

- La cuenta raíz se reserva para emergencias. Las personas y aplicaciones usan identidades propias, y la cuenta raíz se protege con autenticación multifactor.
- Las políticas se escriben con **acciones y recursos concretos**; cualquier `*` requiere justificación.
- **Rechazo explícito > permiso > rechazo implícito.** El rechazo explícito funciona como barrera de seguridad.
- Revocar con rapidez es tan importante como conceder correctamente.

➡️ Siguiente: [Laboratorio 4 · Secretos filtrados y auditoría IAM](../04-secretos/)
