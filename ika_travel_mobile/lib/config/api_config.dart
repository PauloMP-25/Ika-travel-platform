class ApiConfig {
  static const String baseUrl = 'http://127.0.0.1:8000';

  // --- CATALOG (Actividades) ---
  static const String attractions = '$baseUrl/api/v1/catalog/attractions';
  static const String categories = '$baseUrl/api/v1/catalog/categories';

  static String attractionDetail(int id) =>
      '$baseUrl/api/v1/catalog/attractions/$id';

  // --- WEATHER (Clima) ---
  static const String weatherCurrent = '$baseUrl/api/v1/weather/current';
  static const String weatherForecast = '$baseUrl/api/v1/weather/forecast';
  static const String weatherAlerts = '$baseUrl/api/v1/weather/alerts';

  // --- FAVORITES ---
  static String toggleFavorite(int id) =>
      '$baseUrl/api/v1/catalog/attractions/$id/favorite';

  // --- AUTH & USUARIOS ---
  static const String authLogin = '$baseUrl/api/v1/auth/login';
  static const String authRegister = '$baseUrl/api/v1/auth/register';
  static const String usersMe = '$baseUrl/api/v1/users/me';

  // --- TRAFFIC & INCIDENTS (Tráfico e Incidentes Viales) ---
  /// Clave API configurable para tráfico real (TomTom Developer).
  /// Se inyecta mediante `--dart-define=TOMTOM_API_KEY=tu_clave` o en runtime.
  static const String tomtomApiKey = String.fromEnvironment(
    'TOMTOM_API_KEY',
    defaultValue: '',
  );

  /// Bounding Box representativo del área metropolitana de Ica y Panamericana Sur
  /// Formato requerido por TomTom: minLon,minLat,maxLon,maxLat
  static const String bboxIca = '-75.82,-14.15,-75.65,-13.95';

  /// URI oficial para consultar incidentes viales reales en TomTom Traffic v5
  /// Utiliza Uri.https para codificación segura según RFC 3986 y filtra incidentes activos (present).
  static Uri tomtomIncidentDetailsUri({
    required String apiKey,
    String bbox = bboxIca,
  }) {
    return Uri.https(
      'api.tomtom.com',
      '/traffic/services/5/incidentDetails',
      {
        'key': apiKey,
        'bbox': bbox,
        'language': 'es-ES',
        'timeValidityFilter': 'present',
        'fields':
            '{incidents{type,geometry{type,coordinates},properties{id,iconCategory,magnitudeOfDelay,events{description,code},startTime,endTime,from,to,length,delay}}}',
      },
    );
  }

  /// URL en formato String para retrocompatibilidad
  static String tomtomIncidentDetailsUrl({
    required String apiKey,
    String bbox = bboxIca,
  }) =>
      tomtomIncidentDetailsUri(apiKey: apiKey, bbox: bbox).toString();
}

