# Lista de verificación de seguridad en la nube

La lista se utiliza en el cierre del taller como instrumento de autoevaluación. Cada participante marca los controles que su organización ya cumple. Cada bloque corresponde a un laboratorio. Corresponde al Anexo I del [documento académico](../docs/Taller_Nube_Privada_Seguridad_APA.pdf).

## Red y exposición (Laboratorio 1)
- [ ] Los servicios administrativos no se publican en Internet; se accede a ellos mediante una red privada virtual, un bastión o SSM.
- [ ] Las reglas de cortafuegos y los grupos de seguridad no permiten `0.0.0.0/0` salvo en puertos públicos justificados.
- [ ] Existe un inventario periódico de puertos y direcciones públicas.

## Almacenamiento (Laboratorio 2)
- [ ] El bloqueo de acceso público está activado a nivel de cuenta.
- [ ] Los archivos se comparten con URL prefirmadas con caducidad, no con contenedores públicos.
- [ ] Los contenedores críticos (respaldos, registros) tienen versionado o bloqueo de objetos.
- [ ] El cifrado en reposo está activado por defecto.

## Identidad (Laboratorio 3)
- [ ] La cuenta raíz tiene autenticación multifactor, no tiene claves de acceso y no se usa en la operación diaria.
- [ ] Cada persona y cada aplicación tiene su propia identidad.
- [ ] Las políticas usan acciones y recursos específicos; cada `*` está justificado por escrito.
- [ ] Existen rechazos explícitos (o SCP) para las acciones destructivas.
- [ ] Existe un procedimiento probado para revocar credenciales en minutos.

## Secretos (Laboratorio 4)
- [ ] No hay secretos en el código, en las imágenes ni en archivos versionados.
- [ ] Se escanean secretos antes de cada commit y en el repositorio (*push protection*).
- [ ] Los secretos se almacenan en un gestor con rotación.
- [ ] Los procesos automatizados usan credenciales temporales (roles, OIDC), no claves permanentes.
- [ ] Se auditan los permisos que permiten escalar privilegios (`iam:*Policy*`, `iam:PassRole`).

## Auditoría y aseguramiento (Laboratorio 5)
- [ ] Las imágenes se escanean en el proceso de integración y se bloquean las vulnerabilidades críticas.
- [ ] La infraestructura como código se analiza antes de cada despliegue.
- [ ] La versión 2 del servicio de metadatos (IMDSv2) es obligatoria en todas las instancias.
- [ ] El registro de la API (CloudTrail o equivalente) está activado, centralizado y protegido contra borrado.
- [ ] Existen alertas para accesos denegados repetidos y cambios en las identidades.

## Lecturas recomendadas
- Cloud Security Alliance. *Top Threats to Cloud Computing 2024*.
- Center for Internet Security. *CIS Benchmarks* para AWS, Azure, GCP y Docker.
- OWASP. *Secrets Management Cheat Sheet* y *Cloud-Native Application Security Top 10*.
- MITRE. Matriz ATT&CK para entornos en la nube (IaaS, SaaS, proveedor de identidad).
- Laboratorios intencionalmente vulnerables para práctica adicional: *CloudGoat* (Rhino Security Labs) y *flaws.cloud*.
