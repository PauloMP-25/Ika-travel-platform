import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiService {
  Future<List<Map<String, dynamic>>> obtenerActividades() async {
    try {
      print('⏳ Conectando a: ${ApiConfig.attractions}');

      // 👇 AUMENTAMOS EL TIMEOUT A 30 SEGUNDOS
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
          return {
            'id': item['id'],
            'titulo': item['name'] ?? 'Sin título',
            'subtitulo': item['district'] ?? 'Ica',
            'imagen':
                item['cover_image_url'] ?? 'https://via.placeholder.com/150',
            'imagenes_detalle': [
              item['cover_image_url'] ?? 'https://via.placeholder.com/150',
            ],
          };
        }).toList();
      } else {
        print('❌ Error del servidor. Código: ${response.statusCode}');
        // Si el servidor falla, devolvemos una lista vacía para no romper la app
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      // Si hay timeout o error de red, devolvemos una lista vacía
      return [];
    }
  }
}
