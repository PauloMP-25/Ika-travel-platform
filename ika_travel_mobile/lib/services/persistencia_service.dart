import 'dart:convert';
import 'almacenamiento/interfaz.dart';

// Importación condicional: web → localStorage / io → archivo / stub → memoria
import 'almacenamiento/implementacion_stub.dart'
    if (dart.library.html) 'almacenamiento/implementacion_web.dart'
    if (dart.library.io) 'almacenamiento/implementacion_io.dart';

export 'almacenamiento/interfaz.dart';

/// Servicio de persistencia para Ika Travel.
///
/// Detecta automáticamente la plataforma en tiempo de compilación:
/// - Flutter Web (Chrome): usa localStorage del navegador
/// - Android / iOS / Desktop: usa archivo en directorio temporal (dart:io)
/// - Tests unitarios: usa mapa en memoria
///
/// Uso:
/// ```dart
/// final ps = PersistenciaService();
/// await ps.guardarJson('itinerario', jsonMap);
/// final mapa = await ps.leerJson('itinerario');
/// ```
class PersistenciaService {
  static final PersistenciaService _instancia = PersistenciaService._();
  factory PersistenciaService() => _instancia;

  late final GestorAlmacenamiento _gestor;

  PersistenciaService._() {
    _gestor = crearAlmacenamiento();
  }

  /// Guarda un mapa como JSON bajo [clave].
  Future<void> guardarJson(String clave, Map<String, dynamic> mapa) async {
    await _gestor.escribir(clave, jsonEncode(mapa));
  }

  /// Lee y decodifica el JSON guardado bajo [clave].
  /// Retorna null si no existe o si hay un error de decodificación.
  Future<Map<String, dynamic>?> leerJson(String clave) async {
    try {
      final raw = await _gestor.leer(clave);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Elimina el valor guardado bajo [clave].
  Future<void> eliminar(String clave) async {
    await _gestor.eliminar(clave);
  }
}
