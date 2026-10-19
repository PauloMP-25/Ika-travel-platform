import 'package:flutter/material.dart';

class Traducciones {
  static const List<Locale> supportedLocales = [Locale('es'), Locale('en')];

  static String get(String key, Locale locale) {
    final isEn = locale.languageCode == 'en';

    final Map<String, Map<String, String>> textos = {
      'inicio': {'es': 'Inicio', 'en': 'Home'},
      'actividades': {'es': 'Actividades', 'en': 'Activities'},
      'mapa': {'es': 'Mapa', 'en': 'Map'},
      'pronostico': {'es': 'Pronóstico', 'en': 'Forecast'},
      'favoritos': {'es': 'Favoritos', 'en': 'Favorites'},
      'mas': {'es': 'Más', 'en': 'More'},

      'configuracion': {'es': 'Configuración', 'en': 'Settings'},
      'preferencias': {'es': 'Preferencias', 'en': 'Preferences'},
      'notificaciones': {
        'es': 'Notificaciones push',
        'en': 'Push notifications',
      },
      'recibir_alertas': {
        'es': 'Recibir alertas del clima',
        'en': 'Receive weather alerts',
      },
      'modo_oscuro': {'es': 'Modo oscuro', 'en': 'Dark mode'},
      'cambiar_apariencia': {
        'es': 'Cambiar apariencia de la app',
        'en': 'Change app appearance',
      },
      'region': {'es': 'Región', 'en': 'Region'},
      'idioma_app': {'es': 'Idioma de la app', 'en': 'App language'},
      'cuenta': {'es': 'Cuenta', 'en': 'Account'},
      'cerrar_sesion': {'es': 'Cerrar sesión', 'en': 'Log out'},
      'seleccionar_idioma': {
        'es': 'Seleccionar idioma',
        'en': 'Select language',
      },

      'ahora_en_ica': {'es': 'Ahora en Ica', 'en': 'Now in Ica'},
      'ver_recomendacion': {
        'es': 'Ver recomendación del día',
        'en': 'See recommendation of the day',
      },
      'sol': {'es': 'Sol', 'en': 'Sun'},
      'nublado': {'es': 'Nublado', 'en': 'Cloudy'},
      'viento': {'es': 'Viento', 'en': 'Wind'},
      'humedad': {'es': 'Humedad', 'en': 'Humidity'},
      'uv': {'es': 'UV', 'en': 'UV'},
      'buscar_actividad': {
        'es': 'Buscar actividad o lugar',
        'en': 'Search activity or place',
      },

      'mis_favoritos': {'es': 'Mis Favoritos', 'en': 'My Favorites'},
      'mis_alertas': {'es': 'Mis Alertas', 'en': 'My Alerts'},
      'mejor_hora': {
        'es': 'Mejor hora para visitar',
        'en': 'Best time to visit',
      },
      'consejos': {'es': 'Consejos para el turista', 'en': 'Tips for tourists'},
      'sobre_app': {'es': 'Sobre la app', 'en': 'About the app'},
      'compartir_app': {'es': 'Compartir app', 'en': 'Share app'},
      'contacto': {'es': 'Contacto o ayuda', 'en': 'Contact or help'},

      'alertas': {'es': 'Alertas', 'en': 'Alerts'},
      'historial': {'es': 'Historial', 'en': 'History'},
      'detalle_dia': {'es': 'Detalle del Día', 'en': 'Day Details'},
      'resumen_plan': {'es': 'Resumen del plan', 'en': 'Plan summary'},
      'indice_condicion': {
        'es': 'Índice de condición',
        'en': 'Condition index',
      },
      'temperatura': {'es': 'Temperatura', 'en': 'Temperature'},
      'nubosidad': {'es': 'Nubosidad', 'en': 'Cloudiness'},
      'lluvia': {'es': 'Lluvia', 'en': 'Rain'},

      'pronostico_general': {
        'es': 'Pronóstico general',
        'en': 'General forecast',
      },
      'hoy': {'es': 'Hoy', 'en': 'Today'},
      'manana': {'es': 'Mañana', 'en': 'Tomorrow'},
      'siete_dias': {'es': '7 días', 'en': '7 days'},
      'por_horas': {'es': 'Por horas', 'en': 'By hours'},
      'proximos_dias': {'es': 'Próximos días', 'en': 'Next days'},
    };

    return textos[key]?[isEn ? 'en' : 'es'] ?? key;
  }
}
