import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiService {
  Future<List<Map<String, dynamic>>> obtenerActividades() async {
    try {
      print('⏳ Conectando a: ${'${ApiConfig.attractions}?page_size=30'}');

      // 👇 AUMENTAMOS EL TIMEOUT A 30 SEGUNDOS
      final response = await http
          .get(Uri.parse('${ApiConfig.attractions}?page_size=30'))
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

        final mapaImagenesLocales = {
          'Oasis de Huacachina': 'assets/images/carrusel_1_huacachina.jpg',
          'Cañón de los Perdidos': 'assets/images/act_reserva1.jpg',
          'Bodegas de Subtanjalla': 'assets/images/act_vinos.jpg',
          'Pueblo de Cachiche': 'assets/images/carrusel_2_vinos.jpg',
          'Plaza de Armas de Ica': 'assets/images/carrusel_3_sandboarding.jpg',
          'Playa La Mina': 'assets/images/act_reserva1.jpg',
          'Playa Roja': 'assets/images/act_reserva1.jpg',
          'Playa El Chaco': 'assets/images/act_ballestas1.jpg',
          'Playa Hermosa de Marcona': 'assets/images/act_reserva1.jpg',
          'Islas Ballestas': 'assets/images/act_ballestas1.jpg',
          'Reserva Nacional de Paracas': 'assets/images/act_reserva1.jpg',
          'Bodega Tacama': 'assets/images/act_vinos.jpg',
        };
        return items.map((item) {
          final nombre = item['name']?.toString() ?? 'Sin título';
          final imgLocal = mapaImagenesLocales[nombre] ?? 'assets/images/carrusel_1_huacachina.jpg';
          return {
            'id': item['id'],
            'titulo': nombre,
            'subtitulo': item['district'] ?? 'Ica',
            'imagen': imgLocal,
            'imagen_remota': item['cover_image_url'],
            'imagenes_detalle': [
              imgLocal,
              item['cover_image_url'] ?? 'assets/images/carrusel_1_huacachina.jpg',
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
