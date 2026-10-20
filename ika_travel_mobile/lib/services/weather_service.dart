import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class WeatherService {
  // 1. Obtener el clima actual
  Future<Map<String, dynamic>?> obtenerClimaActual() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.weatherCurrent))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Error al obtener clima: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión clima: $e');
      return null;
    }
  }

  // 2. 👇 NUEVO: Obtener el pronóstico (por horas y días)
  Future<Map<String, dynamic>?> obtenerPronostico() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.weatherForecast))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Error al obtener pronóstico: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión pronóstico: $e');
      return null;
    }
  }

  // 3. Obtener recomendación de la IA para un atractivo o la del día
  Future<Map<String, dynamic>?> obtenerRecomendacionDelDia() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.recommendationOfDay))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('❌ Error al obtener recomendación del día: $e');
      return null;
    }
  }

  // 4. Obtener recomendaciones filtradas para todos los atractivos
  Future<List<dynamic>> obtenerRecomendaciones() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.recommendations))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener recomendaciones: $e');
      return [];
    }
  }

}
