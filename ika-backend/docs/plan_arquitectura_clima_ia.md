# Plan de Arquitectura: Motor de Recomendaciones Climáticas con IA (RF-06)

**Proyecto:** Ika Travel & Experience  
**Fecha de Definición:** 2026-09-26  
**Tecnologías Clave:** Cloud Computing, Ciencia de Datos (Data Engineering), Inteligencia Artificial (Prompt Engineering), APIs y Servicios Meteorológicos, Tecnología Móvil.

---

## 1. Pipeline de Extracción y Limpieza (Data Engineering)
Las APIs meteorológicas (Open-Meteo y WeatherAPI) devuelven miles de datos. Para ahorrar costos en Base de Datos y Tokens de IA, un "Celery Worker" ejecutará llamadas periódicas y extraerá únicamente estos **10 Campos de Oro**:

1. **`temperature_c`**: Temperatura real.
2. **`feelslike_c`**: Sensación térmica (Vital en el desierto).
3. **`wind_kph`**: Velocidad del viento sostenido.
4. **`gust_kph`**: Ráfagas de viento (Alertas de seguridad para Tubulares/Paracas).
5. **`uv`**: Índice de radiación Ultravioleta (Recomendación de bloqueador).
6. **`humidity`**: Porcentaje de humedad relativa.
7. **`chance_of_rain` / `precip_mm`**: Probabilidad o nivel de precipitación.
8. **`cloud`**: Cobertura de nubes (Útil para fotografía o atardeceres).
9. **`vis_km`**: Visibilidad (Alertas de conducción o neblina).
10. **`condition_text`**: Descripción amigable ("Despejado", "Parcialmente nublado").

*Estrategia de Interpolación:* Si alguna API devuelve datos con saltos (ej. cada 3 horas), el sistema Backend realizará una interpolación matemática para completar los vacíos, garantizando un formato estricto de **1 fila por hora por atractivo turístico**.

---

## 2. Estrategia de Almacenamiento (Cloud & Database)
**Estrategia:** *Ventana de tiempo deslizante (Sliding Window)*
- Para mantener la ligereza de la base de datos principal, solo se guardará el pronóstico de los próximos **3 a 5 días**.
- Cada vez que el Celery Worker traiga nueva información, **sobreescribirá** los datos pasados.
- Esto reduce drásticamente el uso de Cloud Storage y agiliza las lecturas (`SELECT` ultra rápidos).

---

## 3. Disparo y Generación de la IA (Cloud Computing & AI)
**Estrategia:** *A demanda (On-Demand)*
Para evitar cobros astronómicos de los servicios de Inteligencia Artificial (ej. OpenAI, Gemini, Claude), el motor de IA **no se ejecutará cada hora en segundo plano**. 
El flujo será:
1. Las APIs actualizan la Base de Datos cada hora (Costo casi cero).
2. El turista abre la app y presiona el botón **"Planificar mi día"**.
3. *Recién en ese momento*, el Backend extrae el clima de la BD y dispara el llamado al modelo generativo.

---

## 4. Contexto del Turista (Data Science & NoSQL)
La IA cruzará el clima con el perfil exacto del turista usando un sistema **Híbrido**:
1. **Perfil Estático (Onboarding):** Tags que el usuario marcó al registrarse (Aventura, Relax, Cultura, etc.).
2. **Minería de Datos (Redis / NoSQL):** Base de datos de alta velocidad que acumula qué actividades "Guardó en Favoritos" el usuario o en cuáles hizo más clics, armando un mapa de calor de sus intenciones sin que él lo diga explícitamente.

---

## 5. Comunicación App Móvil <-> Backend (Tecnología Móvil)
**Estrategia de Prompts y Respuesta:**
- Para reducir el consumo de tokens, el Backend enviará el Prompt a la IA estructurado en etiquetas `<XML>`.
- La IA tendrá la orden estricta de devolver únicamente un **JSON Estructurado** (sin saludos ni texto markdown envolvente). 

**Estructura esperada del JSON (Ejemplo base):**
```json
[
  {
    "hora_sugerida": "09:00",
    "actividad_id": "sandboard_huacachina",
    "titulo": "Aventura en las Dunas",
    "motivo_climatico": "La velocidad del viento a las 09:00 es de solo 8 km/h y la arena no estará tan caliente (21°C).",
    "alertas_seguridad": ["UV Moderado: Usa bloqueador", "Lleva agua"]
  }
]
```
Esto permitirá que la App Móvil dibuje interfaces gráficas (Cards nativas) hermosas y dinámicas en lugar de un bloque de texto aburrido.
