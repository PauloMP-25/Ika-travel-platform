# Versión Web de Ika Travel

La app web **no es un segundo frontend**: es el mismo proyecto
`ika_travel_mobile` compilado para navegador. Las pantallas, la navegación,
los servicios y los estilos son exactamente los mismos; lo único que cambia
es un envoltorio que centra la interfaz y tres adaptaciones de plataforma.

---

## 1. Qué se cambió

| Archivo | Cambio | Afecta a Android/Windows |
|---|---|---|
| `lib/config/contenedor_web.dart` | **Nuevo.** Centra la app en una columna de 430 px en escritorio | No: devuelve el hijo tal cual si no es web |
| `lib/main.dart` | Aplica el contenedor y omite la pantalla de permisos en web | Solo en web |
| `lib/services/excepciones_api.dart` | **Nuevo.** `ErrorApi` sustituye a `HttpException` | No: mismo mensaje |
| `lib/services/api_client.dart` | Se quitó `import 'dart:io'` | No |
| `web/index.html` | Título, descripción y client ID de Google | No |
| `Dockerfile.web`, `nginx.conf`, `.dockerignore` | **Nuevos.** Despliegue | No |

### El diseño centrado

En escritorio la app se muestra centrada, con un ancho máximo de **430 px** y
los laterales en gris muy claro. No hay marco de teléfono: se ve la interfaz
directamente.

`ContenedorWeb` no solo recorta visualmente, también ajusta el `MediaQuery`:
las pantallas que miden el ancho (chips, rejillas, la barra inferior) creen
que están en un teléfono y se acomodan igual que en el móvil. Sin esto, el
diseño se vería recortado en vez de adaptado.

En una ventana estrecha o en un móvil, la app ocupa **todo** el espacio, sin
márgenes.

### Por qué se quitó `dart:io`

`api_client.dart` importaba `dart:io` solo para lanzar `HttpException`. Esa
librería no existe en el navegador, así que la versión web dependía de un
detalle frágil del compilador. Ahora usa `ErrorApi`, que conserva el mismo
formato de mensaje (`Error 404: ...`) y además expone el código HTTP.

---

## 2. Limitaciones conocidas en web

Ninguna funcionalidad se eliminó; estas degradan solas y de forma controlada.

| Función | En web | Motivo |
|---|---|---|
| **Pantalla de permisos** | No se muestra | El navegador pide ubicación y micrófono solo cuando se usan. SMS y llamadas no existen como permiso |
| **SMS automático del SOS** | No disponible | Usa un canal nativo de Android (`sms_directo`). El código ya lo detecta y cae a WhatsApp |
| **WhatsApp del SOS** | Funciona | `wa.me` abre WhatsApp Web |
| **Llamar / `tel:` / `sms:`** | Depende del equipo | En un móvil abre la app correspondiente; en escritorio suele no hacer nada |
| **Ubicación GPS** | Funciona, **requiere HTTPS** | La API del navegador bloquea geolocalización en HTTP |
| **Dictado por voz** | Solo Chrome y Edge | Firefox y Safari no implementan la Web Speech API. Ya está en `try/catch` |
| **Detección de choques** | No disponible | Necesita acelerómetro nativo |
| **Favoritos y preferencias** | Funcionan | El almacenamiento ya elegía `localStorage` en web |

> El modo sin conexión (los 12 lugares de respaldo) funciona igual en web, así
> que la app nunca se ve vacía aunque el backend no responda.

---

## 3. Compilar

```bash
cd ika_travel_mobile
flutter build web --release \
  --dart-define=API_URL=https://api.tu-dominio.pe \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... \
  --dart-define=GEMINI_API_KEY=... \
  --dart-define=TOMTOM_API_KEY=...
```

El resultado queda en `build/web`.

> ⚠️ **Flutter congela estos valores dentro del JavaScript al compilar.** No
> son secretos de servidor, pero por eso mismo **nunca** debe pasarse aquí la
> clave de admin ni credenciales de base de datos: cualquiera puede leerlas
> con "Ver código fuente".

Para probar en local:

```bash
flutter run -d chrome --dart-define=API_URL=https://api.tu-dominio.pe
```

---

## 4. Desplegar en Dokploy

### 4.1 Crear la aplicación

1. En Dokploy: **Create Application** → tipo **Dockerfile**.
2. Repositorio: `PauloMP-25/Ika-travel-platform`, rama `main`.
3. **Docker Context Path**: `.` (la **raíz del repositorio**)
4. **Dockerfile Path**: `ika_travel_mobile/Dockerfile.web`

> Las rutas `COPY` del Dockerfile son relativas a la raíz del repositorio.
> Si se pone `ika_travel_mobile` como contexto, el despliegue falla con
> `failed to calculate checksum "/nginx.conf": not found`.

### 4.2 Build Arguments

| Nombre | Valor |
|---|---|
| `API_URL` | `https://api.tu-dominio.pe` (sin `/api/v1` al final) |
| `GOOGLE_WEB_CLIENT_ID` | El client ID de tipo *Web* |
| `GEMINI_API_KEY` | Opcional: activa el traductor por IA |
| `TOMTOM_API_KEY` | Opcional: activa el tráfico |

Van como **build arguments**, no como variables de entorno: Nginx sirve
archivos ya compilados y no puede inyectar nada en tiempo de ejecución.

### 4.3 Dominio

- **Port**: `80`
- Activar **HTTPS** (Let's Encrypt). Es obligatorio: sin HTTPS el navegador
  bloquea la geolocalización y Google Sign-In.

### 4.4 Rutas al recargar

Ya está resuelto en `nginx.conf` con `try_files $uri $uri/ /index.html`. Sin
esa línea, recargar con F5 en cualquier ruta daría 404.

---

## 5. Lo que hay que configurar fuera del código

### CORS en el backend

El backend ya permite todos los orígenes (`ORIGENES_CORS=*` en
`.env.production.example`), así que funciona de entrada. **Para producción
conviene restringirlo** al dominio real:

```
ORIGENES_CORS=https://app.tu-dominio.pe
```

### Google Sign-In

El dominio web debe estar en **Orígenes de JavaScript autorizados** del
cliente OAuth de tipo *Web* en Google Cloud Console. Si falta, el botón de
Google falla aunque el client ID sea correcto.

---

## 6. Qué falta por verificar

Lo siguiente **no se ha podido comprobar** todavía y debe hacerse antes de dar
la web por terminada:

1. **Comunicación real con el backend.** La URL configurada
   (`https://dreary-flap-stole.ngrok-free.dev`) responde **404**, así que la
   web se probó funcionando con los datos de respaldo. Hay que recompilar con
   la URL del VPS y comprobar que el catálogo llega de la BD.
2. **Recorrido visual completo** en escritorio y en móvil.
3. **Google Sign-In en web**, una vez registrado el dominio.
