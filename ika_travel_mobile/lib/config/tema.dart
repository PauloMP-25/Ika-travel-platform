import 'package:flutter/material.dart';

/// Paleta de la app. Centralizada: cambiar aquí refresca toda la interfaz.
///
/// Identidad de Ica: dunas (naranja cálido) + oasis/laguna (turquesa).
/// Se buscó un look más vivo y limpio, manteniendo contraste accesible.
class AppColores {
  // Texto / base
  static const Color marronOscuro = Color(0xFF2E2723); // texto principal
  static const Color grisTexto = Color(0xFF6E6257); // texto secundario
  static const Color arenaFondo = Color(0xFFFBF7F1); // fondo claro
  static const Color blancoTarjeta = Colors.white;

  // Acento principal (dunas) — más vivo que el anterior #D97724
  static const Color naranjaBoton = Color(0xFFF26419);
  static const Color naranjaClaro = Color(0xFFFFE6D5); // fondos suaves del acento

  // Acento secundario (laguna / oasis)
  static const Color turquesaOasis = Color(0xFF0E9AA7);
  static const Color turquesaClaro = Color(0xFFD6F1F3);

  // Apoyos
  static const Color verdeOasis = Color(0xFF2E9E5B);
  static const Color azulParacas = Color(0xFF1565C0);
  static const Color rojoAlerta = Color(0xFFE23B3B);
}
