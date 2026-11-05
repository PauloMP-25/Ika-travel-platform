import 'package:flutter/material.dart';

import 'traducciones.dart';

final ValueNotifier<Locale> idiomaActivo = ValueNotifier(const Locale('es'));

void cambiarIdioma(String codigoIdioma) {
  if (Traducciones.supportedLocales.any(
    (l) => l.languageCode == codigoIdioma,
  )) {
    idiomaActivo.value = Locale(codigoIdioma);
  }
}
