# Guía del facilitador

Esta guía corresponde al Anexo J del [documento académico](Taller_Nube_Privada_Seguridad_APA.pdf).

## Preparación (una semana antes)

- El facilitador envía el enlace del repositorio y solicita a los participantes ejecutar `scripts/instalar-herramientas.sh` y `scripts/verificar-entorno.sh` en sus equipos. La mayoría de los problemas del día del taller provienen de instalaciones incompletas o de redes saturadas al descargar imágenes.
- Prepara una **máquina virtual de Kali Linux de respaldo** (OVA) para quienes no cuenten con un entorno funcional.
- Recorre los cinco laboratorios en un equipo limpio con las versiones vigentes. Este recorrido incluye los comandos `mc` de los Laboratorios 2, 3 y 5 y el escaneo con Trivy, que el documento señala como verificación previa obligatoria.

## Guion por bloques

| Bloque | Tiempo | Mensaje clave | Errores frecuentes |
|---|---|---|---|
| Introducción | 20 min | Las brechas en la nube se originan sobre todo en configuraciones del cliente | — |
| Laboratorio 1 | 30 min | Lo que se publica es superficie de ataque | Grupo `docker` sin recargar; puertos ocupados |
| Laboratorio 2 | 45 min | El acceso público casi nunca es la necesidad real; se usan URL prefirmadas | Conflicto con Midnight Commander |
| Pausa | 10 min | | |
| Laboratorio 3 | 40 min | La identidad es el nuevo perímetro; el rechazo explícito prevalece | Contraseñas de menos de 8 caracteres; omitir `--user` |
| Laboratorio 4 | 35 min | Un secreto que llegó a Git está comprometido | `gitleaks detect` sustituido por `gitleaks git` en versiones recientes |
| Laboratorio 5 | 30 min | Se escanea antes de desplegar | Base de Trivy sin descargar y sin conexión |
| Cierre | 15 min | Lista de verificación y reto final | — |

Si el tiempo es insuficiente, pueden omitirse el versionado del Laboratorio 2, la traza del Laboratorio 3 y la parte de registros del Laboratorio 5 sin afectar los objetivos específicos.

## Introducción sugerida (20 min)

1. Pregunta al grupo qué servicios en la nube utiliza a diario sin advertirlo (correo, fotografías, banca).
2. Presentación de IaaS, PaaS y SaaS.
3. Modelos de despliegue: nube pública, privada, comunitaria e híbrida. Se aclara que el taller construye una nube privada en miniatura.
4. Modelo de responsabilidad compartida: seguridad *de* la nube frente a seguridad *en* la nube.
5. Principales amenazas según la Cloud Security Alliance (2024), cada una asociada al laboratorio que la aborda.

## Reto final

El facilitador ejecuta el siguiente bloque en el equipo de cada participante sin mostrarlo. El bloque introduce tres configuraciones inseguras. El reto se supera cuando el participante identifica y corrige las tres con `mc anonymous list`, `mc admin user list` y `mc admin user info`.

Pista que se entrega: *«hay un contenedor que responde a desconocidos, alguien con demasiado poder y alguien que ya no debería estar»*.

```bash
source scripts/entorno.sh
mc mb --ignore-existing nube/reto-auditoria
echo "bandera{bucket_abierto}" | mc pipe nube/reto-auditoria/flag.txt
mc anonymous set download nube/reto-auditoria                      # error 1
mc admin user add nube becario 'Becario-2026'
mc admin policy attach nube consoleAdmin --user becario            # error 2
mc admin user add nube ex-empleado 'ExEmpleado-2026'
mc admin policy attach nube readwrite --user ex-empleado           # error 3 (cuenta huérfana)
```

## Cierre

Los participantes ejecutan `./scripts/lab.sh down`, o `./scripts/lab.sh reset` si desean repetir el taller. El facilitador comparte el [solucionario](../soluciones/) y la [lista de verificación](../recursos/checklist-seguridad.md).
