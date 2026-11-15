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
  final ids = await _favService.obtenerIdsFavoritos();
  if (ids.isEmpty) return;

  final lugares = await LugaresService().obtenerLugares();
  final favs = List<Map<String, dynamic>>.from(listaFavoritos.value);
  var agregados = 0;

  for (final id in ids) {
    final lugar = lugares.firstWhere(
      (l) => l.id == id,
      orElse: () => lugares.first,
    );
    if (lugar.id != id) continue; // No está en el catálogo cargado.

    final yaEsta = favs.any((f) => f['titulo'] == lugar.nombre);
    if (yaEsta) continue;

    favs.add(lugar.aFavorito());
    agregados++;
  }

  if (agregados > 0) {
    listaFavoritos.value = favs;
    debugPrint('[Favoritos] $agregados favoritos recuperados del servidor.');
  }
}
