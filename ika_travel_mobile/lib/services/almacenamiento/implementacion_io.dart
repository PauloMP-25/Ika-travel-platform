import 'dart:io';
import 'interfaz.dart';

/// Implementación de almacenamiento para Android/iOS/Desktop usando dart:io.
/// Guarda JSON en el directorio temporal del sistema.
///
/// LIMITACIÓN CONOCIDA: En producción mobile se recomienda usar path_provider
/// para obtener el directorio de documentos del usuario. El directorio temporal
/// puede ser purgado por el SO en condiciones de memoria baja.
/// Para habilitar path_provider en Windows se necesita Developer Mode activo.
class AlmacenamientoIo implements GestorAlmacenamiento {
  Future<File> _archivo(String clave) async {
    // Usamos Directory.systemTemp (dart:io puro, sin path_provider)
    final dir = Directory.systemTemp;
    return File('${dir.path}${Platform.pathSeparator}ika_travel_$clave.json');
  }

  @override
  Future<String?> leer(String clave) async {
    try {
      final f = await _archivo(clave);
      if (await f.exists()) return await f.readAsString();
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> escribir(String clave, String valor) async {
    try {
      final f = await _archivo(clave);
      await f.writeAsString(valor);
    } catch (_) {}
  }

  @override
  Future<void> eliminar(String clave) async {
    try {
      final f = await _archivo(clave);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// Factor de creación para importación condicional
GestorAlmacenamiento crearAlmacenamiento() => AlmacenamientoIo();
