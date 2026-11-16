import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Encaja la app dentro de una columna centrada cuando se abre en un
/// navegador de escritorio.
///
/// La app está diseñada para el teléfono: estirada a 1920 px se ve rota
/// (textos de una línea kilométricos, tarjetas deformadas). En vez de
/// rediseñar cada pantalla, la web muestra la misma interfaz móvil centrada,
/// con los laterales en un gris muy claro.
///
/// Dos detalles que importan:
/// - En Android, iOS y Windows **no hace absolutamente nada**: devuelve el
///   hijo tal cual, así que no puede romper la versión móvil.
/// - No solo recorta visualmente: también ajusta el `MediaQuery`, para que
///   las pantallas que miden el ancho (chips, rejillas) crean que están en un
///   teléfono y se acomoden igual que en el móvil.
class ContenedorWeb extends StatelessWidget {
  /// Ancho de la columna de contenido. Equivale a un teléfono grande.
  static const double anchoMaximo = 430;

  final Widget child;

  const ContenedorWeb({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final mq = MediaQuery.of(context);

    // En un móvil o en una ventana angosta, la app ocupa todo: nada de
    // márgenes que desperdicien pantalla.
    if (mq.size.width <= anchoMaximo) return child;

    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: esOscuro ? const Color(0xFF141414) : const Color(0xFFF2F3F5),
      child: Center(
        child: Container(
          width: anchoMaximo,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: esOscuro ? 0.5 : 0.10),
                blurRadius: 24,
              ),
            ],
          ),
          child: MediaQuery(
            // El alto se mantiene; solo se acota el ancho.
            data: mq.copyWith(size: Size(anchoMaximo, mq.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
