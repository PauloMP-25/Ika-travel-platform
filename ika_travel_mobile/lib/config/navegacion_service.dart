import 'package:flutter/material.dart';

/// Controla la pestaña activa de la barra inferior sin crear instancias
/// duplicadas de `MainScaffold`.
class NavegacionService {
  const NavegacionService._();

  /// Clave global de navegación para abrir diálogos, overlays o pantallas
  /// desde cualquier servicio o listener sin necesitar un BuildContext explícito.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Índices de las pestañas de `MainScaffold`, en el mismo orden.
  static const int tabInicio = 0;
  static const int tabActividades = 1;
  static const int tabMapa = 2;
  static const int tabPronostico = 3;
  static const int tabTraducir = 4;

  /// Pestaña actual de la barra inferior.
  static final ValueNotifier<int> indiceTabNotifier = ValueNotifier<int>(
    tabInicio,
  );

  /// Id del lugar que el mapa debe centrar y ampliar. La pantalla del mapa lo
  /// escucha, hace zoom sobre ese punto y vuelve a ponerlo en `null`.
  static final ValueNotifier<String?> lugarEnfocadoNotifier =
      ValueNotifier<String?>(null);

  static int get indiceActual => indiceTabNotifier.value;

  /// Cambia de pestaña y, si estamos en una pantalla apilada encima, regresa
  /// a la principal para que la barra inferior vuelva a verse.
  static void cambiarTab(int index, [BuildContext? context]) {
    indiceTabNotifier.value = index;
    if (context != null && Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  static void irAInicio([BuildContext? context]) =>
      cambiarTab(tabInicio, context);

  static void irAActividades([BuildContext? context]) =>
      cambiarTab(tabActividades, context);

  static void irAMapa([BuildContext? context]) => cambiarTab(tabMapa, context);

  static void irAPronostico([BuildContext? context]) =>
      cambiarTab(tabPronostico, context);

  /// Abre el mapa centrado y ampliado en un lugar concreto.
  ///
  /// Es lo que hace el botón "Ver en el mapa" del detalle: cierra la pantalla
  /// actual, salta a la pestaña del mapa y le pide enfocar ese punto.
  static void irAMapaConLugar(String idLugar, [BuildContext? context]) {
    lugarEnfocadoNotifier.value = idLugar;
    cambiarTab(tabMapa, context);
  }
}
