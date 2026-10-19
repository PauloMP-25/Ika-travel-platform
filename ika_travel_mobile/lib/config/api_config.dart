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
}
