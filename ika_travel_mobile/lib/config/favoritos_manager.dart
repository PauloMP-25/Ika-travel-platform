import 'package:flutter/material.dart';

final ValueNotifier<List<Map<String, dynamic>>> listaFavoritos = ValueNotifier(
  [],
);

// Función para agregar o quitar de favoritos
void toggleFavorito(Map<String, dynamic> actividad) {
  final favs = List<Map<String, dynamic>>.from(listaFavoritos.value);

  final index = favs.indexWhere(
    (elemento) => elemento['titulo'] == actividad['titulo'],
  );

  if (index >= 0) {
    favs.removeAt(index); // Si existe, lo quitamos
  } else {
    favs.add(actividad); // Si no existe, lo agregamos
  }

  listaFavoritos.value = favs; // Notificamos el cambio
}

// Función para saber si una actividad es favorita
bool esFavorito(String titulo) {
  return listaFavoritos.value.any((elemento) => elemento['titulo'] == titulo);
}
