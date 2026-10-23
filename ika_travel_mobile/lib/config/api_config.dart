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
}
