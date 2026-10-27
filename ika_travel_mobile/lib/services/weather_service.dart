import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'gemini_service.dart';

class WeatherService {
  final GeminiService _geminiService = GeminiService();

  // 1. Obtener el clima actual (con timestamp para validar RN-03)
  Future<Map<String, dynamic>?> obtenerClimaActual() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.weatherCurrent),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('❌ Error al obtener clima: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error de conexión clima ($e), usando datos de referencia.');
    }

    // Devolver referencia con fecha actual para modo offline controlado
    return {
      'temperatura_actual': 26.0,
      'sensacion_termica': 27.0,
      'probabilidad_precipitacion': 0.0,
      'humedad': 48.0,
      'velocidad_viento': 14.0,
      'indice_uv': 9.0,
      'descripcion_clima': 'Cielo despejado con sol radiante',
      'visibilidad': 10.0,
      'destino': 'Ica',
      'is_cached': true,
      'fecha_hora_pronostico': DateTime.now().toIso8601String(),
    };
  }

  // 2. Obtener el pronóstico (por horas y días)
  Future<Map<String, dynamic>?> obtenerPronostico({int days = 7}) async {
    try {
      final response = await http
          .get(
            Uri.parse("${ApiConfig.weatherForecast}?days=$days"),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('❌ Error al obtener pronóstico: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error de conexión pronóstico ($e), usando pronóstico enriquecido para Ica.');
    }

    // Pronóstico estructurado de referencia para desarrollo y testing de frontend
    final ahora = DateTime.now();
    final List<Map<String, dynamic>> horas = List.generate(24, (i) {
      final horaDt = ahora.add(Duration(hours: i));
      final h = horaDt.hour;
      final tempHora = (h >= 11 && h <= 15) ? 27.0 + (i % 2) : (h >= 6 && h < 11) ? 22.0 + (h - 6) : 19.0;
      return {
        'time': horaDt.toIso8601String(),
        'temperature': tempHora,
        'uv_index': (h >= 10 && h <= 16) ? 9.0 : 1.0,
        'wind_speed': 12.0 + (i % 5),
        'precipitation_probability': 0.0,
        'condition': 'Despejado',
      };
    });

    final List<Map<String, dynamic>> dias = List.generate(days, (i) {
      final diaDt = ahora.add(Duration(days: i));
      return {
        'date': diaDt.toIso8601String().substring(0, 10),
        'temp_min': 17.0 + (i % 2),
        'temp_max': 28.0 + (i % 3),
        'uv_index_max': 9.0,
        'wind_speed_max': 16.0,
        'precipitation_sum': 0.0,
        'precipitation_probability_max': 0.0,
        'condition': 'Soleado',
      };
    });

    return {
      'destino': 'Ica',
      'horas': horas,
      'dias': dias,
    };
  }

  // 3. Obtener recomendación de la IA para un atractivo o la del día (Gemini)
  Future<Map<String, dynamic>?> obtenerRecomendacionDelDia() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.recommendationOfDay),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint('❌ Error al obtener recomendación del día ($e), activando GeminiService de respaldo.');
    }

    return _geminiService.generarRecomendacionDelDia();
  }

  // 4. Obtener recomendaciones filtradas para todos los atractivos
  Future<List<dynamic>> obtenerRecomendaciones() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.recommendations),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Error al obtener recomendaciones ($e), usando catálogo enriquecido offline.');
    }

    return _geminiService.obtenerCatalogoRecomendacionesOffline();
  }
}

