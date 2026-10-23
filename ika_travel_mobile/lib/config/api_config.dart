class ApiConfig {
  // Permite sobreescribir la URL en compilación con --dart-define=API_URL=https://tu-ngrok.ngrok-free.app
  // o modificar directamente esta variable cuando actives tu túnel.
  static String baseUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://dreary-flap-stole.ngrok-free.dev',
  );

  /// Cabeceras predeterminadas para todas las peticiones HTTP de la app.
  /// Incluye 'ngrok-skip-browser-warning' para evitar que Ngrok bloquee las
  /// peticiones cuando la aplicación corre en Web (Chrome, Edge, etc.).
  static Map<String, String> get defaultHeaders => {
        'Accept': 'application/json',
        'Accept-Language': 'es-PE,es;q=0.9',
        'ngrok-skip-browser-warning': 'true',
      };

  // --- CATALOG (Actividades) ---
  static String get attractions => '$baseUrl/api/v1/catalog/attractions';
  static String get categories => '$baseUrl/api/v1/catalog/categories';

  static String attractionDetail(int id) =>
      '$baseUrl/api/v1/catalog/attractions/$id';

  // --- WEATHER (Clima) ---
  static String get weatherCurrent => '$baseUrl/api/v1/weather/current';
  static String get weatherForecast => '$baseUrl/api/v1/weather/forecast';
  static String get weatherAlerts => '$baseUrl/api/v1/weather/alerts';
  static String get recommendationOfDay => '$baseUrl/api/v1/weather/recommendation-of-the-day';
  static String get recommendations => '$baseUrl/api/v1/weather/recommendations';

  // --- EMERGENCY & SOS ---
  static String get emergencyContacts => '$baseUrl/api/v1/emergency/contacts';
  static String get emergencySos => '$baseUrl/api/v1/emergency/sos';

  // --- FAVORITES ---
  static String toggleFavorite(int id) =>
      '$baseUrl/api/v1/catalog/attractions/$id/favorite';

  // --- AUTH & USUARIOS ---
  static String get authLogin => '$baseUrl/api/v1/auth/login';
  static String get authRegister => '$baseUrl/api/v1/auth/register';
  static String get usersMe => '$baseUrl/api/v1/users/me';

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

