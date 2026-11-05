import 'package:flutter/widgets.dart';

import 'idioma_manager.dart';
import 'traducciones.dart';

class TraduccionesScope extends InheritedNotifier<ValueNotifier<Locale>> {
  const TraduccionesScope({
    super.key,
    required ValueNotifier<Locale> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static Locale localeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TraduccionesScope>();
    return scope?.notifier?.value ?? const Locale('es');
  }

  static String tr(BuildContext context, String key) =>
      Traducciones.get(key, localeOf(context));
}

extension TraduccionesX on BuildContext {
  Locale get locale => TraduccionesScope.localeOf(this);
  String tr(String key) => Traducciones.get(key, locale);
}
