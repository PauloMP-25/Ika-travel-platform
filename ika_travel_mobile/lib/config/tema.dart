import 'package:flutter/material.dart';

/// Paleta de la app. Centralizada: cambiar aquí refresca toda la interfaz.
///
/// Identidad de Ica: dunas (naranja cálido) + oasis/laguna (turquesa).
/// Look más vivo y limpio, manteniendo contraste accesible.
class AppColores {
  // ===================== Base =====================
  /// Texto principal en modo claro.
  static const Color marronOscuro = Color(0xFF2E2723);

  /// Texto secundario en modo claro.
  static const Color grisTexto = Color(0xFF6E6257);

  /// Fondo de pantalla en modo claro.
  static const Color arenaFondo = Color(0xFFFBF7F1);

  /// Fondo de tarjetas en modo claro.
  static const Color blancoTarjeta = Colors.white;

  // ===================== Acentos =====================
  /// Naranja (dunas): acento, botones primarios y foco de inputs. Más vivo
  /// que el anterior #D97724.
  static const Color naranjaBoton = Color(0xFFF26419);

  /// Fondo suave del acento naranja.
  static const Color naranjaClaro = Color(0xFFFFE6D5);

  /// Turquesa (laguna / oasis): acento secundario.
  static const Color turquesaOasis = Color(0xFF0E9AA7);
  static const Color turquesaClaro = Color(0xFFD6F1F3);

  // ===================== Semánticos =====================
  /// Verde oasis: éxito, confirmaciones, estados positivos.
  static const Color verdeOasis = Color(0xFF2E9E5B);

  /// Azul Paracas: información, enlaces, estados neutros.
  static const Color azulParacas = Color(0xFF1565C0);

  /// Rojo: alertas y errores.
  static const Color rojoAlerta = Color(0xFFE23B3B);

  // ===================== Modo oscuro =====================
  static const Color fondoOscuro = Color(0xFF1E1E1E);
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
