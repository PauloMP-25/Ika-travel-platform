import 'package:flutter/material.dart';

import '../services/favorites_service.dart';

final FavoritesService _favoritesService = FavoritesService();

final ValueNotifier<List<Map<String, dynamic>>> listaFavoritos = ValueNotifier(
  [],
);

// Función para agregar o quitar de favoritos (con sincronización remota opcional)
Future<void> toggleFavorito(Map<String, dynamic> actividad) async {
  final favs = List<Map<String, dynamic>>.from(listaFavoritos.value);

  final index = favs.indexWhere(
    (elemento) => elemento['titulo'] == actividad['titulo'],
  );

  final attractionId = actividad['id']?.toString();

  if (index >= 0) {
    favs.removeAt(index); // Si existe, lo quitamos
    listaFavoritos.value = favs; // Notificamos de inmediato para respuesta UI instantánea
    if (attractionId != null) {
      await _favoritesService.toggleRemoteFavorite(attractionId);
    }
  } else {
    favs.add(actividad); // Si no existe, lo agregamos
    listaFavoritos.value = favs; // Notificamos de inmediato
    if (attractionId != null) {
      await _favoritesService.toggleRemoteFavorite(attractionId);
    }
  }
}

// Función para saber si una actividad es favorita
bool esFavorito(String titulo) {
  return listaFavoritos.value.any((elemento) => elemento['titulo'] == titulo);
}
