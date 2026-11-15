# Guía Oficial de Despliegue en VPS — Ika Travel & Experience

Esta guía detalla paso a paso el procedimiento para desplegar la plataforma **Ika Travel** (Backend FastAPI, PostgreSQL, Redis, Celery y Caddy con HTTPS automático) en un Servidor Privado Virtual (VPS), garantizando alta disponibilidad **24 horas al día sin interrupciones**.

---

## 1. Arquitectura de Contenedores en Producción

El despliegue está 100% orquestado mediante `docker-compose.prod.yml` e incluye:
1. **`ika_caddy_prod` (Reverse Proxy & TLS Automático):** Expone los puertos 80 (HTTP) y 443 (HTTPS). Obtiene y renueva automáticamente certificados SSL válidos de Let's Encrypt para tu dominio sin intervención manual.
2. **`ika_api_prod` (FastAPI Backend):** Expone los servicios REST, WebSockets y la IA de recomendaciones de Gemini. Ejecuta migraciones automáticas (`alembic upgrade head`) y población climática al arranque.
3. **`ika_db_prod` (PostgreSQL 15):** Base de datos relacional con volumen persistente (`postgres_data_prod`) y healthcheck activo.
4. **`ika_redis_prod` (Redis 7):** Caché ultrarrápida (AOF persistente) para consensus meteorológico y bróker de mensajería.
5. **`ika_celery_worker_prod` & `ika_celery_beat_prod`:** Tareas programadas en segundo plano (actualización climática cada 3 horas, verificación de alertas y purga de logs antiguos).

---

## 2. Requisitos Previos en el VPS

- **Sistema Operativo:** Ubuntu 22.04 LTS o Ubuntu 24.04 LTS (recomendado).
- **Recursos Mínimos:** 1 vCPU, 2 GB de RAM (recomendado 4 GB o habilitar 2 GB de Swap).
- **Puertos de Red Abiertos (Firewall / Security Groups):**
  - Puerto `22` (SSH para administración).
  - Puerto `80` (HTTP para validación de certificados Let's Encrypt).
  - Puerto `443` (HTTPS para el tráfico seguro de la aplicación móvil).
- **Dominio o Subdominio:** Un registro DNS tipo `A` que apunte tu dominio (ej. `api.ikatravel.pe`) hacia la IP pública de tu VPS.

---

## 3. Instalación de Docker y Docker Compose en el VPS

Si el VPS es nuevo, ejecuta los siguientes comandos vía SSH:

```bash
# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias necesarias
sudo apt install -y curl apt-transport-https ca-certificates gnupg lsb-release

# Añadir repositorio oficial de Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker Engine y Docker Compose Plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Permitir ejecutar Docker sin sudo (opcional)
sudo usermod -aG docker $USER
newgrp docker
```

---

## 4. Clonación del Repositorio y Configuración Segura

1. En el VPS, clona el repositorio de GitHub:
   ```bash
   git clone https://github.com/tu-organizacion/ika-travel-platform.git
   cd ika-travel-platform/ika-backend
   ```

2. **Configura el archivo de variables de producción `.env.production`:**
   > ⚠️ **REGLA DE SEGURIDAD CRÍTICA:** Nunca subas el archivo `.env.production` a Git. Ya se encuentra protegido en el `.gitignore`.

   Copia la plantilla de ejemplo:
   ```bash
   cp .env.production.example .env.production
   ```

3. Abre el archivo con tu editor preferido (ej. `nano`):
   ```bash
   nano .env.production
   ```

4. **Llena los siguientes valores indispensables:**
   - `DOMAIN_NAME`: Coloca tu dominio público (ej. `api.ikatravel.pe`). Si por ahora solo tienes IP, coloca la IP pública (ej. `123.45.67.89`).
   - `EMAIL_NOTIFICACIONES_ADMIN`: Correo para la cuenta de DIRCETUR y alertas de Let's Encrypt.
   - `POSTGRES_PASSWORD`: Coloca una contraseña segura para PostgreSQL.
   - `CLAVE_SECRETA_JWT`: Genera una clave aleatoria ejecutando:
     ```bash
     openssl rand -hex 32
     ```
   - `GEMINI_API_KEY`: Tu clave de Google AI Studio.
   - `OPENWEATHERMAP_API_KEY`: Clave de OpenWeatherMap.
   - `WEATHERAPI_API_KEY`: Clave de WeatherAPI.
   - `GOOGLE_CLIENT_IDS`: `575307622274-shcaqq8vgqgqitc82rjp43m3ujt7dvg8.apps.googleusercontent.com`
   - Guarda los cambios con `Ctrl + O`, `Enter` y sal con `Ctrl + X`.

---

## 5. Despliegue de los Contenedores

Ejecuta el despliegue con un único comando:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

### ¿Qué hace automáticamente este comando?
1. Compila la imagen optimizada de Python 3.12 con todas las librerías de producción.
2. Inicia los contenedores de PostgreSQL y Redis y espera a que sus healthchecks estén en estado `healthy`.
3. El contenedor `api` ejecuta el script `entrypoint.sh`, el cual:
   - Espera la conexión a PostgreSQL.
   - Ejecuta las migraciones de base de datos (`alembic upgrade head`).
   - Inserta el catálogo inicial verificado de Ica y el usuario administrador oficial de DIRCETUR (`admin@dircetur.gob.pe`).
4. Al arrancar FastAPI, el `lifespan` ejecuta automáticamente la tarea `poblar_clima_al_arranque()`, consultando las 3 APIs climáticas y almacenando las métricas en caché.
5. Caddy solicita automáticamente el certificado TLS/SSL y empieza a recibir peticiones seguras vía HTTPS.

---

## 6. Verificación y Monitoreo del Sistema

1. **Revisar el estado de los contenedores:**
   ```bash
   docker compose -f docker-compose.prod.yml ps
   ```
   *Todos los contenedores deben figurar en estado `Up` o `Up (healthy)`.*

2. **Ver los logs en tiempo real:**
   ```bash
   # Logs del backend FastAPI y consumo de tokens de Gemini
   docker compose -f docker-compose.prod.yml logs -f api

   # Logs de Caddy (solicitudes HTTP y certificados)
   docker compose -f docker-compose.prod.yml logs -f caddy
   ```

3. **Verificar el endpoint de salud (Healthcheck):**
   ```bash
   curl -k https://localhost/health
   # Respuesta esperada: {"status":"ok","clima_fresco":true,...}
   ```

---

## 7. Conexión con la Aplicación Móvil Flutter

Una vez el VPS esté en línea:
1. En el proyecto móvil (`ika_travel_mobile/lib/config/api_config.dart`), actualiza `baseUrl`:
   ```dart
   static const String baseUrl = 'https://api.ikatravel.pe'; // Tu dominio HTTPS
   ```
2. Genera el instalador de producción (Release APK o AAB):
   ```bash
   flutter build apk --release
   ```
3. Ahora la aplicación móvil se comunicará las 24 horas del día con tu VPS mediante HTTPS cifrado y seguro.

---

## 8. Mantenimiento y Operaciones Frecuentes

### Actualizar el Backend con Nuevos Cambios
Cuando el equipo suba nuevas funcionalidades a GitHub:
```bash
cd ika-travel-platform/ika-backend
git pull origin main
docker compose -f docker-compose.prod.yml up -d --build
```

### Hacer un Respaldo (Backup) de la Base de Datos
```bash
docker exec -t ika_db_prod pg_dump -U ika_usuario ika_travel_bd > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restaurar un Respaldo
```bash
cat backup_archivo.sql | docker exec -i ika_db_prod psql -U ika_usuario -d ika_travel_bd
```

### Reiniciar Servicios
```bash
docker compose -f docker-compose.prod.yml restart
```

---
*Documentación elaborada por el equipo de ingeniería de Ika Travel & Experience para despliegue de alta disponibilidad en VPS.*
