import 'package:flutter/material.dart';

// Este ValueNotifier guarda si el modo oscuro está activo o no
final ValueNotifier<bool> modoOscuroActivo = ValueNotifier(false);

// Función para cambiar el modo
void toggleModoOscuro(bool isDark) {
  modoOscuroActivo.value = isDark;
}
