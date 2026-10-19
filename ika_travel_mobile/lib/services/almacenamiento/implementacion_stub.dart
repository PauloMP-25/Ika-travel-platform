import 'interfaz.dart';

/// Fallback en memoria (sin persistencia real).
/// Se usa cuando ni dart:html ni dart:io están disponibles.
class AlmacenamientoStub implements GestorAlmacenamiento {
  final Map<String, String> _cache = {};

  @override
  Future<String?> leer(String clave) async => _cache[clave];

  @override
  Future<void> escribir(String clave, String valor) async {
    _cache[clave] = valor;
  }

  @override
  Future<void> eliminar(String clave) async {
    _cache.remove(clave);
  }
}

/// Factor de creación para importación condicional
GestorAlmacenamiento crearAlmacenamiento() => AlmacenamientoStub();
