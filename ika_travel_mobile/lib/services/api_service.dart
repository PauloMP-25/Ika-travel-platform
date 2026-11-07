import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiService {
  Future<List<Map<String, dynamic>>> obtenerActividades() async {
    try {
      debugPrint('⏳ Conectando a: ${'${ApiConfig.attractions}?page_size=30'}');

      final response = await http
          .get(
            Uri.parse('${ApiConfig.attractions}?page_size=30'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        debugPrint(' Respuesta recibida de atractivos');

        final data = json.decode(utf8.decode(response.bodyBytes));

        final List<dynamic> items;
        if (data is List) {
          items = data;
        } else {
          items = data['items'] ?? data['data'] ?? [];
        }

        final mapaImagenesLocales = {
          'Oasis de Huacachina': 'assets/images/carrusel_1_huacachina.jpg',
          'Huacachina Sandboarding & Buggy':
              'assets/images/detalle_sandboarding_1.jpg',
          'Cañón de los Perdidos': 'assets/images/act_buggy1.jpg',
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
          'Santuario del Señor de Luren': 'assets/images/carrusel_2_vinos.jpg',
        };

        return items.map((item) {
          final nombre = item['name']?.toString() ?? 'Sin título';
          final imgLocal =
              mapaImagenesLocales[nombre] ??
              'assets/images/carrusel_1_huacachina.jpg';
          final rawCats = item['categories'] as List<dynamic>? ?? [];
          final categorias = rawCats
              .map((c) {
                if (c is Map) return c['name']?.toString() ?? '';
                return c.toString();
              })
              .where((c) => c.isNotEmpty)
              .toList();

          // 🔎 DIAGNÓSTICO: ver qué trae cada ítem del backend
          debugPrint(
            '🔎 API ITEM: $nombre | id=${item['id']} | keys=${item.keys.toList()}',
          );

          return {
            'id': item['id'],
            'titulo': nombre,
            'subtitulo': item['district'] ?? 'Ica',
            'categoria': categorias.isNotEmpty ? categorias.first : 'Aventura',
            'categorias': categorias,
            'descripcion': item['description'] ?? '',
            'imagen': imgLocal,
            'imagen_remota': item['cover_image_url'],
            'imagenes_detalle': [
              imgLocal,
              if (item['cover_image_url'] != null)
                item['cover_image_url'].toString(),
            ],
          };
        }).toList();
      } else {
        debugPrint(
          '❌ Error del servidor de atractivos: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint(
        '❌ Error al obtener actividades ($e), usando catálogo oficial local.',
      );
    }

    // Catálogo oficial predefinido de la región Ica (RF-02)
    return const [
      {
        'id': '1',
        'titulo': 'Oasis de Huacachina',
        'subtitulo': 'Ica',
        'categoria': 'Aventura',
        'categorias': ['Aventura', 'Naturaleza'],
        'descripcion': 'Laguna natural rodeada de inmensas dunas de arena en medio del desierto costero de Ica.',
        'imagen': 'assets/images/carrusel_1_huacachina.jpg',
        'imagenes_detalle': [
          'assets/images/carrusel_1_huacachina.jpg',
          'assets/images/detalle_sandboarding_1.jpg',
          'assets/images/detalle_sandboarding_2.jpg',
        ],
      },
      {
        'id': '2',
        'titulo': 'Islas Ballestas',
        'subtitulo': 'Paracas',
        'categoria': 'Naturaleza',
        'categorias': ['Naturaleza', 'Fauna'],
        'descripcion': 'Santuario marino con lobos marinos, pingüinos de Humboldt y aves guaneras en formaciones rocosas.',
        'imagen': 'assets/images/act_ballestas1.jpg',
        'imagenes_detalle': [
          'assets/images/act_ballestas1.jpg',
          'assets/images/detalle_ballestas_2.jpg',
          'assets/images/detalle_ballestas_3.jpg',
        ],
      },
      {
        'id': '3',
        'titulo': 'Reserva Nacional de Paracas',
        'subtitulo': 'Paracas',
        'categoria': 'Naturaleza',
        'categorias': ['Naturaleza', 'Desierto'],
        'descripcion': 'Área natural protegida donde el desierto se une con el océano Pacífico, incluyendo Playa Roja y La Mina.',
        'imagen': 'assets/images/act_reserva1.jpg',
        'imagenes_detalle': [
          'assets/images/act_reserva1.jpg',
          'assets/images/detalle_reserva_2.jpg',
          'assets/images/detalle_reserva_3.jpg',
        ],
      },
      {
        'id': '4',
        'titulo': 'Bodega Tacama y Viñedos',
        'subtitulo': 'Ica',
        'categoria': 'Gastronomía',
        'categorias': ['Gastronomía', 'Cultura'],
        'descripcion': 'El viñedo más antiguo de Sudamérica, célebre por sus piscos galardonados y vinos de tradición.',
        'imagen': 'assets/images/act_vinos.jpg',
        'imagenes_detalle': [
          'assets/images/act_vinos.jpg',
          'assets/images/detalle_vinos_2.jpg',
          'assets/images/detalle_vinos_3.jpg',
        ],
      },
      {
        'id': '5',
        'titulo': 'Cañón de los Perdidos',
        'subtitulo': 'Ocucaje, Ica',
        'categoria': 'Aventura',
        'categorias': ['Aventura', 'Geología'],
        'descripcion': 'Formación geológica profunda en el desierto de Ocucaje con fósiles marinos milenarios.',
        'imagen': 'assets/images/act_buggy1.jpg',
        'imagenes_detalle': [
          'assets/images/act_buggy1.jpg',
          'assets/images/detalle_buggy_2.jpg',
          'assets/images/detalle_buggy_3.jpg',
        ],
      },
      {
        'id': '6',
        'titulo': 'Santuario del Señor de Luren',
        'subtitulo': 'Ica',
        'categoria': 'Cultura',
        'categorias': ['Cultura', 'Historia'],
        'descripcion': 'Templo católico emblemático y centro de la devoción tradicional del pueblo iqueño.',
        'imagen': 'assets/images/carrusel_2_vinos.jpg',
        'imagenes_detalle': ['assets/images/carrusel_2_vinos.jpg'],
      },
      {
        'id': '7',
        'titulo': 'Pueblo de Cachiche',
        'subtitulo': 'Ica',
        'categoria': 'Cultura',
        'categorias': ['Cultura', 'Misticismo'],
        'descripcion': 'Famoso pueblo de leyendas y curandería tradicional con la Palmera de las Siete Cabezas.',
        'imagen': 'assets/images/detalle_buggy_2.jpg',
        'imagenes_detalle': ['assets/images/detalle_buggy_2.jpg'],
      },
    ];
  }
}
