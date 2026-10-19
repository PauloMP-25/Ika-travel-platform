import 'package:flutter/material.dart';

// Guarda el idioma actual (por defecto español)
final ValueNotifier<Locale> idiomaActivo = ValueNotifier(const Locale('es'));

// Función para cambiar el idioma
void cambiarIdioma(String codigoIdioma) {
  idiomaActivo.value = Locale(codigoIdioma);
}
