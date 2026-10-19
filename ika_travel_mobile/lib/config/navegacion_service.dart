import 'package:flutter/material.dart';

/// Servicio global para gestionar el cambio de pestañas de la navegación inferior
/// sin perder la barra de navegación principal ni crear instancias duplicadas de MainScaffold.
class NavegacionService {
  // Notificador reactivo con el índice de pestaña actual de la barra inferior
  static final ValueNotifier<int> indiceTabNotifier = ValueNotifier<int>(0);

  static int get indiceActual => indiceTabNotifier.value;

  /// Cambia a una pestaña específica y regresa a la pantalla principal si estamos en una pantalla secundaria
  static void cambiarTab(int index, [BuildContext? context]) {
    indiceTabNotifier.value = index;
    if (context != null && Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  static void irAInicio([BuildContext? context]) => cambiarTab(0, context);
  static void irAActividades([BuildContext? context]) => cambiarTab(1, context);
  static void irAMapa([BuildContext? context]) => cambiarTab(2, context);
  static void irAPronostico([BuildContext? context]) => cambiarTab(3, context);
  static void irAFavoritos([BuildContext? context]) => cambiarTab(4, context);
}
