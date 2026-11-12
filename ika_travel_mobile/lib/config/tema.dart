import 'package:flutter/material.dart';

class AppColores {
  // ===================== Base =====================

  /// Marrón oscuro: texto principal en modo claro.
  static const Color marronOscuro = Color(0xFF382E27);

  /// Naranja: color de acento, botones primarios y foco de inputs.
  static const Color naranjaBoton = Color(0xFFD97724);

  /// Arena clara: fondo de pantalla en modo claro.
  static const Color arenaFondo = Color(0xFFF7F2EB);

  /// Blanco: fondo de tarjetas en modo claro.
  static const Color blancoTarjeta = Colors.white;

  /// Gris texto: texto secundario en modo claro.
  static const Color grisTexto = Color(0xFF63564D);

  // ===================== Semánticos =====================

  /// Verde oasis: éxito, confirmaciones, estados positivos.
  static const Color verdeOasis = Color(0xFF2E7D32);

  /// Azul Paracas: información, enlaces, estados neutros.
  static const Color azulParacas = Color(0xFF1565C0);

  // ===================== Modo oscuro =====================

  /// Fondo de pantalla en modo oscuro.
  static const Color fondoOscuro = Color(0xFF1E1E1E);

  /// Fondo de tarjetas en modo oscuro.
  static const Color tarjetaOscura = Color(0xFF2C2C2C);

  // ===================== Alias con opacidad =====================
  // Útiles para no repetir `withValues(alpha: ...)` en cada pantalla.

  /// Fondo de inputs en modo claro (arena al 60%).
  static Color get inputFillClaro => arenaFondo.withValues(alpha: 0.6);

  /// Fondo de inputs en modo oscuro (blanco al 6%).
  static Color get inputFillOscuro => Colors.white.withValues(alpha: 0.06);

  /// Borde de foco de inputs (naranja al 60%).
  static Color get focoNaranja => naranjaBoton.withValues(alpha: 0.6);
}
