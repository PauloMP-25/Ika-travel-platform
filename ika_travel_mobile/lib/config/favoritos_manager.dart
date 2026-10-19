import 'package:flutter/material.dart';
import '../services/favorites_service.dart';

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
