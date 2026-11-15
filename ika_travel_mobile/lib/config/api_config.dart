class ApiConfig {
  static String baseUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://dreary-flap-stole.ngrok-free.dev',
  );

  static Map<String, String> get defaultHeaders => {
    'Accept': 'application/json',
    'Accept-Language': 'es-PE,es;q=0.9',
    'ngrok-skip-browser-warning': 'true',
  };

  // --- ADMIN DIRCETUR ---
  static const String adminKey = 'secreto';

  static Map<String, String> get adminHeaders => {
    ...defaultHeaders,
    'X-Admin-Key': adminKey,
    'Content-Type': 'application/json',
  };

  static String get adminAgencies => '$baseUrl/api/v1/catalog/admin/agencies';
  static String get adminSyncDircetur =>
      '$baseUrl/api/v1/catalog/admin/agencies/sync-dircetur';
  static String adminValidateAgency(String id) =>
      '$baseUrl/api/v1/catalog/admin/agencies/$id/validate';
  static String adminRevokeAgency(String id) =>
      '$baseUrl/api/v1/catalog/admin/agencies/$id/revoke';

  // Panel DIRCETUR: listado de reportes de incidencia de TODOS los turistas.
  // Ojo: no es la misma ruta que `emergencyReports` (esa solo acepta POST
  // para crear). Pedirle un GET a la de crear devuelve 404/405, que es lo que
  // dejaba el panel de administración siempre vacío.
  // Se protege con el JWT de un usuario con rol admin, no con X-Admin-Key.
  static String get adminEmergencyReports =>
      '$baseUrl/api/v1/emergency/admin/reports';

  static String adminEmergencyReportDetail(String id) =>
      '$baseUrl/api/v1/emergency/admin/reports/$id';

  /// Reportes que emitió el propio usuario (para que confirme que llegaron).
  static String get myEmergencyReports =>
      '$baseUrl/api/v1/emergency/my-reports';

  // --- GEO & ATRACTIVOS CERCANOS ---
  // `limit` tiene tope 50 en el backend y `radius_m` tope 100 000 m.
  static String geoNearby({
    double lat = -14.0685,
    double lon = -75.7288,
    int radiusM = 300000,
    int limit = 100,
  }) =>
      '$baseUrl/api/v1/geo/nearby?lat=$lat&lon=$lon&radius_m=$radiusM'
      '&limit=$limit';

  // --- CATALOG (Actividades) ---
  static String get attractions => '$baseUrl/api/v1/catalog/attractions';
  static String get categories => '$baseUrl/api/v1/catalog/categories';

  // `attraction.id` es un UUID, no un entero.
  static String attractionDetail(String id) =>
      '$baseUrl/api/v1/catalog/attractions/$id';

  // --- WEATHER (Clima) ---
  static String get weatherBase => '$baseUrl/api/v1/weather';
  static String get weatherCurrent => '$weatherBase/current';
  static String get weatherForecast => '$weatherBase/forecast';
  static String get weatherAlerts => '$weatherBase/alerts';
  static String get weatherAlertsHistory => '$weatherBase/alerts/history';
  static String weatherAlertById(String id) => '$weatherBase/alerts/$id';
  static String get recommendationOfDay =>
      '$weatherBase/recommendation-of-the-day';
  static String get recommendations => '$weatherBase/recommendations';

  // --- AGENCIES & PRESTADORES FORMALES ---
  static String get agencies => '$baseUrl/api/v1/catalog/agencies';
  static String agencyDetail(String id) =>
      '$baseUrl/api/v1/catalog/agencies/$id';

  // --- EMERGENCY & SOS ---
  static String get emergencyContacts => '$baseUrl/api/v1/emergency/contacts';
  static String get emergencySos => '$baseUrl/api/v1/emergency/sos';

  // (Opcional: si usas esta ruta en otra pantalla pública, déjala.
  // Si solo la usas en el panel admin, puedes borrarla y dejar solo adminEmergencyReports)
  static String get emergencyReports => '$baseUrl/api/v1/emergency/reports';

  // --- FAVORITES ---
  static String toggleFavorite(String id) =>
      '$baseUrl/api/v1/catalog/attractions/$id/favorite';

  // --- AUTH & USUARIOS ---
  static String get authLogin => '$baseUrl/api/v1/auth/login';
  static String get authRegister => '$baseUrl/api/v1/auth/register';

  static String get authGoogle => '$baseUrl/api/v1/auth/login/google';
  static String get usersMe => '$baseUrl/api/v1/users/me';

  // --- GOOGLE SIGN-IN ---
  // Client ID de tipo "Web application" (Google Cloud Console → Credentials).
  // Sin él Android lanza `ApiException: 10` porque no puede emitir el idToken.
  // Inyección en build:
  //   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '575307622274-shcaqq8vgqgqitc82rjp43m3ujt7dvg8.apps.googleusercontent.com',
  );

  // --- IA & GEMINI ---
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // --- TRAFFIC & INCIDENTS ---
  static const String tomtomApiKey = String.fromEnvironment(
    'TOMTOM_API_KEY',
    defaultValue: '',
  );

  static const String bboxIca = '-75.82,-14.15,-75.65,-13.95';

  static Uri tomtomIncidentDetailsUri({
    required String apiKey,
    String bbox = bboxIca,
  }) {
    return Uri.https('api.tomtom.com', '/traffic/services/5/incidentDetails', {
      'key': apiKey,
      'bbox': bbox,
      'language': 'es-ES',
      'timeValidityFilter': 'present',
      'fields': '{incidents{type,geometry{type,coordinates},properties{id,iconCategory,magnitudeOfDelay,events{description,code},startTime,endTime,from,to,length,delay}}}',
    });
  }

  static String tomtomIncidentDetailsUrl({
    required String apiKey,
    String bbox = bboxIca,
  }) => tomtomIncidentDetailsUri(apiKey: apiKey, bbox: bbox).toString();
}
