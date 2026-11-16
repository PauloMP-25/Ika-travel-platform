/// Error devuelto por la API cuando la respuesta no es un 2xx.
///
/// Sustituye a `HttpException` de `dart:io`, que obligaba a importar esa
/// librería en el cliente HTTP. `dart:io` no existe en el navegador, así que
/// la versión web dependía de un detalle frágil del compilador.
///
/// El mensaje conserva el mismo formato que antes ("Error 404: ...") para no
/// romper a quien lo muestre o lo registre.
class ErrorApi implements Exception {
  final String message;
  final Uri? uri;

  const ErrorApi(this.message, {this.uri});

  /// Código HTTP si el mensaje lo trae ("Error 404: ..." -> 404).
  int? get codigo {
    final m = RegExp(r'^Error (\d{3})').firstMatch(message);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  @override
  String toString() =>
      uri == null ? 'ErrorApi: $message' : 'ErrorApi: $message, uri = $uri';
}
