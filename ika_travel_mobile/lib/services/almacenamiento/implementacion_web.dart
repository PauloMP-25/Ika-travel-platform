// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'interfaz.dart';

/// Implementación de almacenamiento para Flutter Web usando localStorage.
/// Los datos persisten entre sesiones mientras no se limpie el almacenamiento del navegador.
class AlmacenamientoWeb implements GestorAlmacenamiento {
  @override
  Future<String?> leer(String clave) async {
    return html.window.localStorage['ika_travel_$clave'];
  }

  @override
  Future<void> escribir(String clave, String valor) async {
    html.window.localStorage['ika_travel_$clave'] = valor;
  }

  @override
  Future<void> eliminar(String clave) async {
    html.window.localStorage.remove('ika_travel_$clave');
  }
}

/// Factor de creación para importación condicional
GestorAlmacenamiento crearAlmacenamiento() => AlmacenamientoWeb();
