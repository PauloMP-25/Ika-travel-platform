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

  static String get adminEmergencyReports =>
      '$baseUrl/api/v1/emergency/reports';

  // --- GEO & ATRACTIVOS CERCANOS ---
  static String geoNearby({
    double lat = -14.0685,
    double lon = -75.7288,
    int radiusM = 100000,
  }) => '$baseUrl/api/v1/geo/nearby?lat=$lat&lon=$lon&radius_m=$radiusM';

  // --- CATALOG (Actividades) ---
  static String get attractions => '$baseUrl/api/v1/catalog/attractions';
  static String get categories => '$baseUrl/api/v1/catalog/categories';

  static String attractionDetail(int id) =>
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
  static String toggleFavorite(int id) =>
      '$baseUrl/api/v1/catalog/attractions/$id/favorite';

  // --- AUTH & USUARIOS ---
  static String get authLogin => '$baseUrl/api/v1/auth/login';
  static String get authRegister => '$baseUrl/api/v1/auth/register';

  static String get authGoogle => '$baseUrl/api/v1/auth/login/google';
  static String get usersMe => '$baseUrl/api/v1/users/me';

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
