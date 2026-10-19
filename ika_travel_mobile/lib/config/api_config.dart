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

  // --- EMERGENCY & SOS ---
  static const String emergencyContacts = '$baseUrl/api/v1/emergency/contacts';
  static const String emergencySos = '$baseUrl/api/v1/emergency/sos';

  // --- FAVORITES ---
  static String toggleFavorite(int id) =>
      '$baseUrl/api/v1/catalog/attractions/$id/favorite';

  // --- AUTH & USUARIOS ---
  static const String authLogin = '$baseUrl/api/v1/auth/login';
  static const String authRegister = '$baseUrl/api/v1/auth/register';
  static const String usersMe = '$baseUrl/api/v1/users/me';
}
