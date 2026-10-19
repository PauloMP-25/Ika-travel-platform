/// Interfaz de almacenamiento persistente para Ika Travel.
/// Se implementa de forma distinta en web (dart:html) y en móvil/desktop (dart:io).
abstract class GestorAlmacenamiento {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> eliminar(String clave);
}
