# Ika Travel & Experience — Backend

Este es el repositorio del backend para la plataforma de turismo inteligente **Ika Travel & Experience**, orientada a mejorar la experiencia de los visitantes en la región de Ica, Perú.

## Stack Tecnológico Seleccionado

- **Lenguaje / Framework:** Python + FastAPI
- **Base de Datos:** PostgreSQL (Relacional)
- **Caché y Tareas en Segundo Plano:** Redis + Celery
- **Arquitectura:** Monolito Modular (Domain-Driven estructurado), diseñado para escalar fácilmente a microservicios en el futuro.

## Estructura de Carpetas

La arquitectura se divide por dominios (feature-based) para facilitar el trabajo en paralelo de los desarrolladores y mantener un bajo acoplamiento.

```text
ika-backend/
├── src/
│   ├── main.py                      # Punto de entrada FastAPI, monta routers
│   ├── config.py                    # Settings (Pydantic), env vars
│   ├── database.py                  # Conexión SQLAlchemy
│   ├── redis_client.py              # Conexión Redis
│   │
│   ├── core/                        # Utilidades core: seguridad, dependencias, middleware
│   ├── modules/                     # Módulos de dominio (El núcleo de la app)
│   │   ├── catalog/                 # Catálogo de destinos y actividades
│   │   ├── weather/                 # Clima e integraciones de IA (Gemini)
│   │   ├── translation/             # Traducción bidireccional
│   │   ├── emergency/               # SOS / Botón de pánico y geolocalización
│   │   ├── reviews/                 # Reseñas, favoritos y fotos
│   │   └── users/                   # Autenticación y gestión de usuarios
│   │
│   └── shared/                      # Utilidades compartidas (ej. paginación, subida de archivos)
│
├── alembic/                         # Migraciones de BD
├── tests/                           # Tests (espejo de la carpeta modules/)
├── celery_worker.py                 # Entrypoint para el worker de Celery
├── docker-compose.yml               # Orquestación local (Postgres, Redis, Backend)
└── Dockerfile                       # Definición de la imagen del contenedor
```

### Justificación de la Arquitectura

1. **Escalabilidad (Migración a Microservicios sin dolor):** Si un dominio como `emergency` o `weather` requiere escalar independientemente en el futuro, es tan simple como aislar y mover su respectiva carpeta.
2. **Paralelización (Ideal para equipos pequeños):** Al tener módulos aislados, el equipo (3 desarrolladores) puede dividirse el trabajo sin fricciones o conflictos (merge conflicts) en git.
3. **Cohesión Alta:** Todo lo relacionado con un mismo tema (como el modelo de base de datos, el esquema pydantic y la lógica) vive en la misma carpeta del módulo.

## Registro de Cambios Recientes (Changelog Inicial)

- **Fase de Setup:**
  - Inicialización del repositorio y de la rama `main`.
  - Creación de la estructura base de carpetas (`src/modules`, `core`, `shared`).
  - Creación de archivos vacíos para inicialización de controladores, esquemas y servicios (`router.py`, `models.py`, `schemas.py`, `service.py`).
  - Configuración inicial de `.gitignore` para entornos Python y archivos temporales de sistema.
  - Generación de este documento (`README.md`) y definición oficial del stack.
