# Taller práctico: nube privada y seguridad de la información en la nube sobre Kali Linux

Taller-laboratorio de **medio día (3 h 45 min)**, de nivel intermedio. En él, cada participante despliega una nube privada en su propia máquina con Kali Linux. Después reproduce las configuraciones inseguras más frecuentes de los entornos en la nube, las explota de forma controlada, las detecta y aplica controles de seguridad normalizados.

> 📄 **Documento académico (norma APA 7.ª edición):** [`docs/Taller_Nube_Privada_Seguridad_APA.pdf`](docs/Taller_Nube_Privada_Seguridad_APA.pdf).
> El documento contiene el marco teórico, la metodología, la matriz de trazabilidad con ISO/IEC 27002:2022 y NIST SP 800-53, y todos los archivos de este repositorio transcritos como anexos.

El taller no requiere cuentas en AWS, Azure ni GCP. Todo se ejecuta en el equipo del participante, sin costo y sin interactuar con sistemas de terceros.

## Arquitectura

```
                        Kali Linux (solo 127.0.0.1)
 ┌──────────────────────────────────────────────────────────────────┐
 │  Herramientas: aws-cli · mc · nmap · curl · gitleaks · trivy · jq │
 │        │                    │                                     │
 │        ▼                    ▼                                     │
 │  ┌──────────────┐    ┌──────────────┐     red Docker "nube"       │
 │  │ Silo (MinIO) │    │ Moto 5.2.3   │                             │
 │  │ S3 + IAM     │    │ API de AWS   │                             │
 │  │ :9000 / :9001│    │ :5000        │                             │
 │  └──────────────┘    └──────────────┘                             │
 └──────────────────────────────────────────────────────────────────┘
```

| Componente | Función en el taller | Equivalente en la nube pública |
|---|---|---|
| **Silo** (bifurcación comunitaria de MinIO) | Almacenamiento de objetos con usuarios y políticas que se aplican efectivamente | Amazon S3 + AWS IAM |
| **Moto** | Emulación de las API de AWS (IAM, STS, Secrets Manager) | Cuenta de AWS de pruebas |
| **Docker** | Ejecución y aislamiento de los servicios | Capa de cómputo del proveedor |

## Agenda

| Horario | Bloque | Temas de seguridad |
|---|---|---|
| 0:00 – 0:20 | Introducción | Modelos de servicio, responsabilidad compartida y amenazas principales |
| 0:20 – 0:50 | [Laboratorio 1 · Despliegue y superficie de ataque](labs/01-nube-privada/) | Exposición de puertos y reconocimiento |
| 0:50 – 1:35 | [Laboratorio 2 · Almacenamiento mal configurado](labs/02-almacenamiento/) | Contenedores públicos, enumeración anónima, URL prefirmadas y versionado |
| 1:35 – 1:45 | Pausa | |
| 1:45 – 2:25 | [Laboratorio 3 · Identidad y mínimo privilegio](labs/03-iam-minio/) | Cuenta raíz, políticas, rechazo explícito y revocación |
| 2:25 – 3:00 | [Laboratorio 4 · Secretos filtrados y auditoría IAM](labs/04-secretos/) | Credenciales en Git, respuesta a incidentes y escalada de privilegios |
| 3:00 – 3:30 | [Laboratorio 5 · Auditoría y aseguramiento](labs/05-auditoria/) | Imágenes vulnerables, infraestructura como código y registros |
| 3:30 – 3:45 | Cierre | [Lista de verificación](recursos/checklist-seguridad.md), reto final y preguntas |

## Inicio rápido

```bash
git clone https://github.com/<usuario>/taller-cloud-seguridad.git
cd taller-cloud-seguridad
chmod +x scripts/*.sh labs/*/*.sh

./scripts/instalar-herramientas.sh   # una sola vez, con conexión a Internet
newgrp docker                        # o cerrar la sesión y volver a entrar
./scripts/verificar-entorno.sh       # todas las comprobaciones deben aparecer como [OK]

./scripts/lab.sh up                  # despliega la nube privada
source scripts/entorno.sh            # carga alias y credenciales en la terminal
```

Órdenes disponibles: `./scripts/lab.sh {up|down|reset|status|logs}`. La orden `reset` devuelve el laboratorio a su estado inicial.

## Requisitos

- Kali Linux 2025.x o posterior (equipo físico, máquina virtual o WSL2), con **4 GB de RAM** como mínimo y 5 GB de disco libre.
- Conexión a Internet **solo** para la instalación previa ([docs/00-preparacion.md](docs/00-preparacion.md)).

## Estructura del repositorio

```
├── docker-compose.yml        Definición de la nube privada
├── .env.example              Credenciales de ejemplo (se copian a .env)
├── scripts/                  Instalación, control y verificación
├── docs/
│   ├── Taller_Nube_Privada_Seguridad_APA.pdf   Documento académico (entregable)
│   ├── 00-preparacion.md     Preparación del entorno
│   └── guia-facilitador.md   Tiempos, mensajes clave y reto final
├── labs/01..05/              Guía de cada laboratorio y archivos de apoyo
├── soluciones/               Solucionario de las preguntas de análisis
└── recursos/                 Lista de verificación de seguridad
```

## Selección de componentes (octubre de 2026)

- **MinIO** archivó su edición comunitaria y, en septiembre de 2026, **eliminó sus imágenes de Docker Hub** (el error `pull access denied for minio/minio`). El taller usa **Silo** (`pgsty/silo`), una bifurcación comunitaria mantenida y compatible con MinIO: mismas variables `MINIO_*`, mismos puertos y el mismo cliente (`mcli`, que se instala como `mc`).
- **Trivy** sufrió un ataque de cadena de suministro en marzo de 2026: las versiones 0.69.4, 0.69.5 y 0.69.6 eran maliciosas. `scripts/verificar-entorno.sh` comprueba que la versión instalada no sea una de ellas.
- Todas las imágenes se fijan por versión (`pgsty/silo:RELEASE.2026-09-16T00-00-00Z`, `motoserver/moto:5.2.3`). Estos tres casos se analizan en el Laboratorio 5 como riesgos reales de cadena de suministro.
- **LocalStack** exige desde marzo de 2026 una cuenta y un token incluso en su plan gratuito. Por ello el taller usa **Moto**, que no requiere registro. Quien disponga de un token de LocalStack puede sustituir el servicio `moto` por LocalStack en el puerto 4566; los comandos `aws` no cambian.

## Uso ético

Las técnicas se aplican **exclusivamente contra el laboratorio propio**. Su uso sobre sistemas ajenos sin autorización escrita constituye un delito en Colombia (Ley 1273 de 2009). Todos los datos personales del taller son ficticios.

## Licencia

Código bajo licencia MIT; contenido didáctico bajo CC BY-SA 4.0. Véase [LICENSE](LICENSE).
