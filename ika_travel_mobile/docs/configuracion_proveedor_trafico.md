# Guía de Configuración: Tráfico en Vivo e Incidentes Viales Reales

**Plataforma:** Ika Travel (`ika_travel_mobile`)  
**Fecha:** Octubre 2026  
**Módulo:** Etapa 4 - Navegación con Tráfico e Incidentes Viales Reales  

---

## 1. Evaluación y Selección del Proveedor para Ica, Perú

Se analizaron los principales proveedores de telemetría vial y capas de incidentes para la región de Ica:

| Proveedor | Endpoint Evaluado | Nivel Gratuito Oficial | Tarjeta de Crédito Obligatoria | Cobertura en Ica | Idoneidad para Ika Travel |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **TomTom Traffic API (v5)** | `incidentDetails` | **2.500 solicitudes/día gratis** (~75.000/mes) | **NO** | Alta (Panamericana Sur PE-1S, casco urbano y accesos turísticos) | **Seleccionado (Óptimo)** |
| **HERE Technologies** | `v7/incidents` | 250.000 transacciones/mes | NO (en plan Freemium) | Media-Alta (principalmente Panamericana) | Alternativa viable |
| **Mapbox Directions** | `driving-traffic` | 100.000 peticiones/mes | NO | Alta | Excelente para ruteo con congestión, pero no entrega lista aislada de incidentes por BBox sin suscripción vectorial |
| **Google Maps Platform** | `Routes API` | Crédito mensual de \$200 USD | **SÍ (desde el día 1)** | Muy Alta | Riesgo alto de sobrecostos al escalar |
| **SUTRAN (Perú)** | Mapa de Alertas | Acceso web público | N/A | Interurbana nacional | No posee API REST pública con SLA garantizado |

### ¿Por qué se seleccionó TomTom Traffic API v5?
1. **Sin tarjeta bancaria requerida:** Permite habilitar pruebas y producción inicial sin ingresar datos de pago.
2. **2.500 peticiones diarias gratuitas:** Con la arquitectura de caché espacial de 5 minutos implementada en `TraficoService`, una sesión de navegación continua consume a lo sumo **12 peticiones por hora**. El límite gratuito cubre más de **200 horas de conducción diaria**.
3. **Endpoint específico de incidentes:** Devuelve atributos estructurados: tipo de incidente (cierre, accidente, obras, congestión), demora estimada en segundos, polilíneas afectadas y la bandera explícita `roadClosed: true`.

---

## 2. Pasos Concretos para Obtener la Clave API Gratuita

1. Ingrese al portal oficial de desarrolladores de TomTom: [https://developer.tomtom.com/](https://developer.tomtom.com/).
2. Haga clic en **"Register"** y cree una cuenta con su correo electrónico (no solicitará tarjeta de crédito).
3. Una vez dentro del panel (**Dashboard**), diríjase a la sección **"Keys" / "My Keys"**.
4. Copie la clave pública asignada (**Consumer Key / API Key**).

---

## 3. Configuración Segura de la Clave en `ika_travel_mobile`

Para evitar subir credenciales privadas al repositorio Git, se soporta inyección por entorno:

### Opción A: Compilación o Ejecución por Terminal (Recomendada)
Inyecte la clave mediante `--dart-define`:
```bash
# Para depuración en Chrome
flutter run -d chrome --dart-define=TOMTOM_API_KEY=tu_clave_aqui

# Para emulador o dispositivo Android
flutter run -d android --dart-define=TOMTOM_API_KEY=tu_clave_aqui
```

### Opción B: Configuración Local en Desarrollo
Si prefiere definirla directamente en su espacio local, modifique `lib/config/api_config.dart`:
```dart
static const String tomtomApiKey = String.fromEnvironment(
  'TOMTOM_API_KEY',
  defaultValue: 'TU_CLAVE_AQUI', // Recuerde no commitear su clave a repositorios públicos
);
```

---

## 4. Política de Caché y Protección contra Solicitudes Excesivas

`TraficoService` implementa las siguientes salvaguardas:
1. **Caché Espacial y Temporal (TTL 5 minutos):** Las consultas dentro de la misma zona delimitada (`bboxIca`) reutilizan los datos en memoria sin disparar llamadas HTTP adicionales.
2. **Bounding Box Optimizado para Ica:**
   - Coordenadas: `-75.82, -14.15, -75.65, -13.95`.
   - Cubre el casco urbano de Ica, la Av. San Martín, la Panamericana Sur (PE-1S), Los Aquijes, Subtanjalla y el Oasis de Huacachina en una sola petición.
3. **Manejo Resiliente de Red:**
   - Si no hay clave API, el sistema reporta `EstadoProveedorTrafico.sinConfigurar` y muestra un indicador amigable en el HUD.
   - Si ocurre un timeout o error 429/403, la navegación vehicular continúa con OSRM sin interrupciones.
4. **Política Estricta de Veracidad:**
   - **No se simulan ni inventan cierres de vías ni accidentes** cuando el servicio está inactivo o sin señal.
   - No se aplican desvíos automáticos salvo que exista una ruta alternativa calculada y validada que no atraviese la zona bloqueada.

---

## 5. Pruebas y Validación Realizadas

Se ejecutaron pruebas exhaustivas en `test/trafico_test.dart` y en la suite general:
- **Parsing de eventos:** Verificación de cierres totales, demoras, obras y accidentes desde JSON de TomTom.
- **Intersección espacial:** Cálculo preciso de distancia entre incidentes y la polilínea del recorrido.
- **Caché y cuotas:** Comprobación de que llamadas repetidas no disparan peticiones HTTP adicionales.
- **Validación de desvíos:** Aprobación de alternativas que evaden cortes viales y rechazo seguro de rutas que también presenten bloqueos.
