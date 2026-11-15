/// Limpieza del texto que generan la IA y el backend antes de mostrarlo.
///
/// Los modelos de lenguaje tienden a adornar las respuestas con emojis
/// ("☀️ ¡Día perfecto! 🏜️"). Queda ruidoso dentro de las tarjetas de la app,
/// que ya tienen sus propios iconos, y además se ve distinto en cada
/// teléfono. Como el texto llega en tiempo de ejecución, no se puede
/// arreglar en el código fuente: hay que limpiarlo al recibirlo.
library;

class TextoIA {
  /// Rangos Unicode de emojis y pictogramas.
  static final RegExp _emojis = RegExp(
    r'[\u{1F000}-\u{1FAFF}]|'   // emojis y símbolos suplementarios
    r'[\u{2600}-\u{27BF}]|'     // misceláneos y dingbats
    r'[\u{2B00}-\u{2BFF}]|'     // flechas y figuras
    r'[\u{FE00}-\u{FE0F}]|'     // selectores de variación (el "️" invisible)
    r'[\u{1F1E6}-\u{1F1FF}]|'   // banderas
    r'\u{200D}',                // unión de emojis compuestos
    unicode: true,
  );

  /// Quita los emojis y deja los espacios ordenados.
  static String limpiar(String? texto) {
    if (texto == null || texto.isEmpty) return '';
    return texto
        .replaceAll(_emojis, '')
        // Espacios dobles que quedan donde estaba el emoji.
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        // Signos que quedaron sueltos al inicio de una línea.
        .replaceAll(RegExp(r'^[ \t]+', multiLine: true), '')
        .trim();
  }

  /// Igual que [limpiar] pero sobre una lista (los consejos de la IA llegan
  /// como `List<dynamic>` desde el JSON).
  static List<String> limpiarLista(List<dynamic>? items) {
    if (items == null) return const [];
    return items
        .map((e) => limpiar(e?.toString()))
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
