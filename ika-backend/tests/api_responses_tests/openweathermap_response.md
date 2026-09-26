# Pruebas de API: OpenWeatherMap

**Fecha de ejecución:** 2026-09-26 00:43:55

---

### 📖 Guía de los campos del JSON (OpenWeatherMap)
- **`list`:** En lugar de `hourly` (por hora), OpenWeatherMap devuelve un arreglo `list` con pronósticos cada **3 horas**.
- **`main.temp`:** La temperatura esperada.
- **`main.humidity`:** La humedad.
- **`wind.speed`:** Velocidad del viento (suele venir en metros/segundo y toca convertirla a km/h multiplicando por 3.6).
- **`weather.description`:** Una descripción del clima (ej: "cielo claro").

#### 🟢 Ventajas / Pros
- La API es increíblemente estable y confiable.
- Una de las bases de datos de estaciones meteorológicas más grandes del mundo.
- Incluye el campo `pop` (Probabilidad de Precipitación).

#### 🔴 Diferencias / Contras respecto a las demás
- **No devuelve datos por hora en su versión gratuita**, sino cada 3 horas. Para tu motor de IA esto puede ser una desventaja porque si el turista pregunta por las 10:00 AM, la API solo te dará datos de las 09:00 AM y 12:00 PM, y el backend tendría que calcular un promedio interpolado.
- En este endpoint gratuito de pronóstico (`/forecast`), **no incluye el Índice UV**, algo que es fundamental para el Sandboarding en Ica.

---
### Atractivo: Huacachina
**Error obteniendo datos:** 401 Client Error: Unauthorized for url: https://api.openweathermap.org/data/2.5/forecast?lat=-14.0875&lon=-75.7626&appid=9adc224e966779c1577ec0cb3cab84a5&units=metric&lang=es

### Atractivo: Cañón de los Perdidos
**Error obteniendo datos:** 401 Client Error: Unauthorized for url: https://api.openweathermap.org/data/2.5/forecast?lat=-14.7552&lon=-75.5139&appid=9adc224e966779c1577ec0cb3cab84a5&units=metric&lang=es

### Atractivo: Cachiche
**Error obteniendo datos:** 401 Client Error: Unauthorized for url: https://api.openweathermap.org/data/2.5/forecast?lat=-14.095&lon=-75.736&appid=9adc224e966779c1577ec0cb3cab84a5&units=metric&lang=es

### Atractivo: Bahía de Paracas
**Error obteniendo datos:** 401 Client Error: Unauthorized for url: https://api.openweathermap.org/data/2.5/forecast?lat=-13.8266&lon=-76.2727&appid=9adc224e966779c1577ec0cb3cab84a5&units=metric&lang=es

### Atractivo: Centro de Ica
**Error obteniendo datos:** 401 Client Error: Unauthorized for url: https://api.openweathermap.org/data/2.5/forecast?lat=-14.0666&lon=-75.7333&appid=9adc224e966779c1577ec0cb3cab84a5&units=metric&lang=es

