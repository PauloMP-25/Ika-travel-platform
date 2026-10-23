# Análisis y Propuesta Técnica: Servicios de Tráfico en Vivo e Incidentes Viales para Ica

**Plataforma:** Ika Travel (`ika_travel_mobile`)  
**Fecha:** Octubre 2026  
**Propósito:** Evaluar y presentar alternativas de proveedores para tráfico vehicular en vivo y cierres viales en la provincia y región de Ica (Perú) antes de asumir compromisos comerciales o dependencias de pago.

---

## 1. Contexto Vial y Desafíos Específicos de Ica

La red vial de Ica presenta características singulares que influyen decisivamente en la elección del proveedor:
1. **Corredor Panamericana Sur (PE-1S):** Eje neurálgico de alta velocidad con tránsito mixto (camiones de carga pesada, buses interprovinciales y autos particulares) susceptible a congestión estacional y cierres esporádicos por mantenimiento o eventos climáticos.
2. **Cinturón Urbano y Centro Histórico (Av. San Martín, Calle Lima, Av. Cutervo, Av. Municipalidad):** Calles angostas, transporte público informal (mototaxis y colectivos) y desvíos frecuentes por obras o festividades (como el Festival Internacional de la Vendimia o procesiones del Señor de Luren).
3. **Acceso a Rutas Turísticas y Desérticas (Oasis de Huacachina, Ruta del Pisco en Subtanjalla/San Juan Bautista, Cañón de los Perdidos):** Vías rurales de un solo carril, tramos no asfaltados y zonas con baja densidad de telemetría de conductores.

---

## 2. Matriz Comparativa de Proveedores

| Proveedor | Cobertura en Ica | Nivel de Detalle de Incidentes | Nivel Gratuito (Free Tier) | Costo Excedente (por 1.000 req) | Requisitos de Integración |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Mapbox Directions (driving-traffic)** | **Alta** (urbana e interurbana) | Medio-Alto (congestión por tramo y cierres viales en rutas) | **100.000 solicitudes/mes gratis** | ~$2.00 - $4.00 USD | Registro en Mapbox, Public Token |
| **Google Maps Platform (Routes API)** | **Excelente** (máxima densidad Android en Ica) | **Excelente** (accidentes, obras, demoras en tiempo real) | **$200 USD crédito mensual** (~28.500 req/mes) | ~$5.00 - $10.00 USD | Cuenta Google Cloud, Tarjeta de crédito activa obligatoria |
| **HERE Technologies (Traffic & Routing API v8)** | **Buena** (Panamericana y avenidas principales) | Alto (reportes de cierres viales categorizados) | **250.000 transacciones/mes gratis** | ~$1.00 USD | Cuenta HERE Developer, API Key (no requiere tarjeta para iniciar) |
| **TomTom Traffic API** | **Media-Buena** (PE-1S y casco urbano) | Alto (Traffic Incidents + Traffic Flow) | **2.500 solicitudes/día gratis** (no comercial) | ~$0.50 - $0.80 USD | Cuenta TomTom Developer, API Key |
| **Waze for Cities Data Feed** | **Muy Alta** (gran comunidad activa en Perú) | **Excelente** (baches, cierres, alertas ciudadanas) | Gratuito bajo convenio institucional | No disponible comercialmente de forma abierta | Convenio municipal o de movilidad urbana |

---

## 3. Análisis Detallado de Cada Alternativa

### A. Mapbox Navigation & Directions API (`mapbox/driving-traffic`)
* **Ventajas:**
  - Capa gratuita generosa (100.000 peticiones mensuales sin costo), ideal para la fase de crecimiento de Ika Travel.
  - SDK de Flutter y compatibilidad directa con capas GeoJSON en `flutter_map`.
  - El perfil `driving-traffic` incorpora automáticamente demoras de tráfico en el cálculo de duración y selección de ruta.
* **Limitaciones:**
  - En trochas hacia zonas desérticas remotas (e.g., Cañón de los Perdidos), los datos de velocidad pueden ser inferidos por falta de sondas activas en tiempo real.
* **Requisitos:**
  - Mapbox Public Access Token.
  - No requiere cuota fija inicial.

### B. Google Maps Platform (Routes API con Traffic)
* **Ventajas:**
  - Es el estándar de facto con mayor precisión en Perú debido a la penetración de smartphones Android con servicios de ubicación activos en Ica.
  - Cobertura inigualable en callejuelas céntricas, mototaxis y desvíos improvisados.
* **Limitaciones:**
  - Modelo de precios agresivo y riesgo de sobrecostos si la aplicación escala sin un estricto sistema de caché.
  - Requiere registrar tarjeta de crédito internacional desde el día uno.
* **Requisitos:**
  - Cuenta GCP corporativa, facturación habilitada y API Key protegida por huella SHA-1 de la app Android.

### C. HERE Technologies (Traffic Vector Tile & Incident API)
* **Ventajas:**
  - Paquete gratuito de 250.000 transacciones mensuales que no exige tarjeta para prototipos y pruebas.
  - Servicio dedicado de incidentes viales (`/traffic/v7/incidents`) que entrega geo-polígonos exactos de cierres de vías.
* **Limitaciones:**
  - Menor granularidad en vías secundarias de distritos como La Tinguiña, Parcona o Salas Guadalupe comparado con Google Maps.

### D. TomTom Traffic API
* **Ventajas:**
  - Excelente separación entre flujo de tráfico continuo (velocidades reales de tramo) e incidentes puntuales.
  - Documentación clara y costos unitarios bajos.
* **Limitaciones:**
  - El límite diario de 2.500 transacciones puede agotarse rápidamente si se consulta en bucle continuo desde cada dispositivo móvil en marcha.

---

## 4. Estrategia de Caché y Ahorro de Peticiones para Ika Travel

Para cualquier proveedor que se elija en el futuro, se recomienda implementar la siguiente arquitectura en `ika_travel_mobile`:
1. **Throttle dinámico por velocidad:** No consultar tráfico mientras el vehículo esté detenido en un semáforo (velocidad < 3 km/h).
2. **Caché por segmentos espaciales (Bounding Box):** Consultar incidentes de la zona Ica-Huacachina cada 3 a 5 minutos a nivel general, en lugar de consultar punto a punto cada 10 segundos.
3. **Respaldo sin conexión (Offline Fallback):** Si el servicio de tráfico no responde o se pierde la conectividad móvil (frecuente en zonas de dunas), degradar elegantemente al cálculo geométrico de OSRM sin interrumpir la interfaz de navegación.

---

## 5. Recomendación y Próximos Pasos

1. **Recomendación para la etapa actual:** Mantener OSRM (`router.project-osrm.org`) para el ruteo libre sin costo y **no agregar dependencias comerciales en este momento**.
2. **Recomendación para la siguiente etapa:** Si se decide incorporar tráfico real, la opción con mejor balance costo-cobertura es **Mapbox Directions (`mapbox/driving-traffic`)** gracias a sus 100.000 solicitudes mensuales gratuitas y soporte nativo GeoJSON.
3. **Aprobación requerida:** Se somete este informe a revisión del equipo antes de gestionar credenciales o modificar el servicio de rutas.
