import 'package:flutter/material.dart';

/// Tope al tamaño de letra del sistema.
///
/// Android deja subir la letra bastante por encima del 100 % (el teléfono de
/// pruebas viene en 145 %), y a partir de cierto punto los botones y los chips
/// se salen de la pantalla. Respetamos que el usuario agrande la letra, pero
/// hasta donde la app sigue siendo usable.
///
/// Vive aquí, y no dentro de `main.dart`, para que las pruebas de desborde
/// puedan aplicar exactamente el mismo límite que la app real.
class EscalaTexto {
  /// Más allá de este factor el diseño deja de caber.
  static const double maxima = 1.3;

  /// Para usar como `builder:` de `MaterialApp`.
  static Widget aplicar(BuildContext context, Widget? child) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: maxima,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
