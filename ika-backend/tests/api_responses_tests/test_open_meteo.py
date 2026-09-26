import json
import requests
import datetime

locations = {
    "Huacachina": {"lat": -14.0875, "lon": -75.7626},
    "Cañón de los Perdidos": {"lat": -14.7552, "lon": -75.5139},
    "Cachiche": {"lat": -14.0950, "lon": -75.7360},
    "Bahía de Paracas": {"lat": -13.8266, "lon": -76.2727},
    "Centro de Ica (Referencia para Huacatoma)": {"lat": -14.0666, "lon": -75.7333}
}

BASE_URL = "https://api.open-meteo.com/v1/forecast"

with open("tests/api_responses_tests/open_meteo_response.md", "w", encoding="utf-8") as f:
    f.write("# Pruebas de API: Open-Meteo\n\n")
    f.write(f"**Fecha de ejecución:** {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
    
    f.write("## 1. Open-Meteo (Sin API Key, totalmente gratuita)\n\n")
    
    for name, coords in locations.items():
        params = {
            "latitude": coords["lat"],
            "longitude": coords["lon"],
            "current": "temperature_2m,relative_humidity_2m,wind_speed_10m,uv_index",
            "hourly": "temperature_2m,relative_humidity_2m,wind_speed_10m,uv_index",
            "timezone": "America/Lima",
            "forecast_days": 1 # Solo el dia de hoy
        }
        
        try:
            resp = requests.get(BASE_URL, params=params, timeout=10)
            resp.raise_for_status()
            data = resp.json()
            
            f.write(f"### Atractivo: {name}\n")
            f.write(f"- **Coordenadas:** {coords['lat']}, {coords['lon']}\n")
            f.write("```json\n")
            f.write(json.dumps(data, indent=4, ensure_ascii=False))
            f.write("\n```\n\n")
        except Exception as e:
            f.write(f"### Atractivo: {name}\n")
            f.write(f"**Error obteniendo datos:** {str(e)}\n\n")

    f.write("---\n")
    f.write("## 2. WeatherAPI y Visual Crossing\n")
    f.write("> **Nota:** Las respuestas para estas APIs están pendientes hasta configurar las API Keys correspondientes.\n")
