import 'package:flutter/material.dart';

import 'tema.dart';

class TemaApp {
  // 1. Fondo de la pantalla (Arena clara o Negro/Gris oscuro)
  static Color fondo(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  // 2. Fondo de las tarjetas (Blanco o Gris oscuro)
  static Color tarjeta(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2C2C2C) : Colors.white;
  }

  // 3. Color del texto principal (Marrón oscuro o Blanco)
  static Color texto(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : AppColores.marronOscuro;
  }

  // 4. Color del texto secundario (Gris claro u oscuro)
  static Color textoSecundario(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white70 : AppColores.grisTexto;
  }
}
