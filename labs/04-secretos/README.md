# Laboratorio 4 · Secretos filtrados y auditoría IAM

⏱️ **35 minutos** · 🎯 **Objetivo:** detectar credenciales filtradas en un repositorio, medir su impacto, gestionar el incidente y auditar permisos peligrosos en una cuenta de AWS emulada.

**Amenaza:** desarrollo de software inseguro y gestión de identidades (CSA, 2024).
**Controles ISO/IEC 27002:2022:** 5.17 Información de autenticación · 5.26 Respuesta a incidentes · 8.4 Acceso al código fuente · 8.28 Codificación segura.

```bash
cd ~/taller-cloud-seguridad/labs/04-secretos
source ../../scripts/entorno.sh
./preparar-escenario.sh
./poblar-iam-aws.sh
```

## Parte A · La credencial que "ya se borró" (15 min)

Un desarrollador escribió las credenciales de su aplicación en el código y luego hizo un commit para retirarlas.

```bash
cd app-vulnerable
git log --oneline
cat config.py                     # la versión actual parece segura
```

### A.1 · Búsqueda manual en el historial

```bash
git log -p | grep -nE 'ACCESS_KEY|SECRET_KEY'
```

### A.2 · Búsqueda automatizada con gitleaks

```bash
gitleaks detect --source . -v
```

> En versiones recientes de gitleaks, el subcomando equivalente es `gitleaks git -v .`.

❓ **Pregunta 1.** ¿En qué commit se encuentra el secreto? ¿Por qué el segundo commit **no** resuelve el problema? ¿Qué ocurriría si el repositorio fuera público en GitHub?

### A.3 · Medición del impacto

gitleaks reporta el commit y el archivo donde está la clave `AKIA...`. La clave secreta suele estar en la línea siguiente del mismo archivo, aunque gitleaks no siempre la marque:

```bash
git show <COMMIT>:config.py        # el commit que reportó gitleaks
mc alias set filtrada http://localhost:9000 <ACCESS_KEY> <SECRET_KEY>
mc ls filtrada/
mc cat filtrada/app-clientes/clientes.csv
```

### A.4 · Respuesta al incidente

El orden es determinante: **primero se revoca y después se limpia.**

```bash
mc admin user disable nube <ACCESS_KEY>      # 1. revocación inmediata
mc ls filtrada/                              # 2. verificación de que dejó de funcionar
mc admin trace nube                          # 3. (en producción) revisión del uso de la credencial
```

En un incidente real se completarían los siguientes pasos:

4. Creación de credenciales nuevas, almacenadas en un **gestor de secretos** y no en el código.
5. Reescritura del historial (`git filter-repo`) solo como medida de higiene: la credencial ya se considera comprometida.
6. Escaneo de secretos antes de cada commit (gitleaks como *pre-commit hook*) y en GitHub (*secret scanning* y *push protection*).

## Parte B · La práctica correcta: un gestor de secretos (5 min)

```bash
awsm secretsmanager list-secrets --query 'SecretList[].Name'
awsm secretsmanager get-secret-value --secret-id prod/app/base-datos \
  --query SecretString --output text | jq
```

❓ **Pregunta 2.** Si la aplicación lee el secreto en tiempo de ejecución, ¿qué permiso IAM necesita exactamente y sobre qué recurso? ¿Qué ventajas ofrece frente a un archivo `.env`?

## Parte C · Auditoría IAM y escalada de privilegios (15 min)

Exploración de la cuenta de AWS emulada:

```bash
awsm iam list-users --query 'Users[].UserName'
awsm iam list-policies --scope Local --query 'Policies[].PolicyName'
awsm iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/DevGestionaIAM --version-id v1
```

Ejecución del auditor incluido (se recomienda leer su código antes: unas 60 líneas de Bash y `jq`):

```bash
./auditar-iam.sh
```

Resultado esperado: tres hallazgos (`AdminTodo` con `*:*`, `DevGestionaIAM` con acciones de escalada y `bot-ci` como administrador con clave permanente).

❓ **Pregunta 3.** El usuario `diego-dev` "solo lee", pero tiene `iam:AttachUserPolicy` sobre `*`. ¿Cómo podría convertirse en administrador de la cuenta en dos pasos?

🔍 **Reto (opcional):** Moto no aplica permisos por defecto, por lo que el reto consiste en escribir la secuencia exacta de comandos `awsm iam ...` que usaría Diego y la política corregida que lo impide.

## ✅ Conclusiones del laboratorio

- Un secreto que llegó a Git está comprometido de forma permanente: **primero se revoca**.
- Los secretos se almacenan en un gestor (Secrets Manager, Vault), no en el código ni en las imágenes.
- Las acciones `iam:*Policy*`, `iam:CreateAccessKey` e `iam:PassRole` equivalen a privilegios de administrador.
- Las claves permanentes para procesos automatizados (`bot-ci`) son un riesgo; se prefieren credenciales temporales (roles, OIDC de GitHub Actions).

➡️ Siguiente: [Laboratorio 5 · Auditoría y aseguramiento](../05-auditoria/)
