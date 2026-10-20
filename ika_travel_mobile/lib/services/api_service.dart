import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiService {
  Future<List<Map<String, dynamic>>> obtenerActividades() async {
    try {
      print('⏳ Conectando a: ${ApiConfig.attractions}');

      final response = await http
          .get(Uri.parse(ApiConfig.attractions))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ Respuesta recibida');

        final data = json.decode(response.body);

        final List<dynamic> items;
        if (data is List) {
          items = data;
        } else {
          items = data['items'] ?? data['data'] ?? [];
        }

        return items.map((item) {
          String categoria = 'General';
          final nombre = (item['name'] ?? '').toString().toLowerCase();

          if (item['categories'] != null &&
              (item['categories'] as List).isNotEmpty) {
            categoria = item['categories'][0]['name'] ?? 'General';
          } else {
            if (nombre.contains('isla') ||
                nombre.contains('playa') ||
                nombre.contains('reserva')) {
              categoria = 'Naturaleza';
            } else if (nombre.contains('museo')) {
              categoria = 'Cultura';
            } else if (nombre.contains('viñedo') ||
                nombre.contains('vinedos') ||
                nombre.contains('bodega')) {
              categoria = 'Gastronomía';
            } else if (nombre.contains('sandboard') ||
                nombre.contains('buggy') ||
                nombre.contains('laguna')) {
              categoria = 'Aventura';
            }
          }

          return {
            'id': item['id'],
            'titulo': item['name'] ?? 'Sin título',
            'subtitulo': item['district'] ?? 'Ica',
            'categoria': categoria,
            'imagen':
                item['cover_image_url'] ?? 'https://via.placeholder.com/150',
            'imagenes_detalle': [
              item['cover_image_url'] ?? 'https://via.placeholder.com/150',
            ],
          };
        }).toList();
      } else {
        print('❌ Error del servidor. Código: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      return [];
    }
  }

  // 👇 NUEVO: Obtener el detalle de una atracción por su ID
  Future<Map<String, dynamic>?> obtenerDetalleAtraccion(String id) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.attractions}/$id'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Error al obtener detalle: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión detalle: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> obtenerRecomendacionesIA() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/v1/weather/recommendations'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Convertimos la lista a un Map para buscarlo fácil por ID
        final Map<String, dynamic> mapa = {};
        for (var item in data) {
          mapa[item['atractivo_id']] = item;
        }
        return mapa;
      } else {
        print('❌ Error al obtener recomendaciones: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión recomendaciones: $e');
      return null;
    }
  }
}
