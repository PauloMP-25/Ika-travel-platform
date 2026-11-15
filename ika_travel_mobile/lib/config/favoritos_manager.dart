import '../models/lugar_modelo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../services/lugares_service.dart';

final ValueNotifier<List<Map<String, dynamic>>> listaFavoritos = ValueNotifier([]);
final FavoritesService _favService = FavoritesService();

// Función para agregar o quitar de favoritos (con sincronización remota si aplica)
void toggleFavorito(Map<String, dynamic> actividad) {
  final favs = List<Map<String, dynamic>>.from(listaFavoritos.value);

  final index = favs.indexWhere(
    (elemento) => elemento['titulo'] == actividad['titulo'],
  );

  if (index >= 0) {
    favs.removeAt(index); // Si existe, lo quitamos localmente
  } else {
    favs.add(actividad); // Si no existe, lo agregamos localmente
  }

  listaFavoritos.value = favs; // Notificamos a la UI inmediatamente

  // Sincronización en segundo plano con el backend
  final String? id = actividad['id']?.toString();
  if (id != null && id.length >= 32) {
    _favService.toggleRemoteFavorite(id);
  }
}

// Función para saber si una actividad es favorita
bool esFavorito(String titulo) {
  return listaFavoritos.value.any((elemento) => elemento['titulo'] == titulo);
}

/// Recupera los favoritos guardados en el servidor y los suma a los locales.
///
/// Se llama al entrar a la app con sesión iniciada, para que los favoritos
/// aparezcan también al cambiar de teléfono o reinstalar. El endpoint solo
/// devuelve los ids, así que el nombre y la imagen salen del catálogo.
Future<void> sincronizarFavoritosDesdeServidor() async {
  final remotos = await _favService.obtenerFavoritosCompletos();
  if (remotos.isEmpty) return;

  final lugares = await LugaresService().obtenerLugares();
  final favs = List<Map<String, dynamic>>.from(listaFavoritos.value);
  var agregados = 0;

  for (final item in remotos) {
    final attractionId = item['attraction_id']?.toString() ?? '';
    if (attractionId.isEmpty) continue;

    // Buscar en catálogo si ya está en memoria
    final enCatalogo = lugares.where((l) => l.id == attractionId).firstOrNull;

    final nombre = item['name']?.toString() ?? enCatalogo?.nombre ?? '';
    if (nombre.isEmpty) continue;

    final yaEsta = favs.any((f) => f['titulo'] == nombre || f['id'] == attractionId);
    if (yaEsta) continue;

    if (enCatalogo != null) {
      favs.add(enCatalogo.aFavorito());
    } else {
      final cover = item['cover_image_url']?.toString();
      final distrito = item['district']?.toString() ?? 'Ica';
      favs.add({
        'id': attractionId,
        'titulo': nombre,
        'subtitulo': distrito,
        'categoria': 'Turismo',
        'imagen': (cover != null && cover.isNotEmpty) ? cover : LugarIca.imagenPorDefecto,
        'imagenes_detalle': [(cover != null && cover.isNotEmpty) ? cover : LugarIca.imagenPorDefecto],
      });
    }
    agregados++;
  }

  if (agregados > 0) {
    listaFavoritos.value = favs;
    debugPrint('[Favoritos] $agregados favoritos recuperados del servidor.');
  }
}
