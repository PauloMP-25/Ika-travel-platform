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

  // 2. Obtener el pronóstico
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

  // 👇 NUEVO: Obtener alertas climáticas reales del backend
  Future<List<dynamic>?> obtenerAlertasClimaticas() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/v1/weather/alerts'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Error al obtener alertas: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión alertas: $e');
      return null;
    }
  }
}
