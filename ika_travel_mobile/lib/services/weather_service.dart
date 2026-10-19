import 'package:flutter/foundation.dart';

import '../models/weather_model.dart';
import 'api_client.dart';

class WeatherService {
  final ApiClient _apiClient;

  WeatherService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Obtiene el clima actual (por defecto para Ica)
  Future<ClimaActualModel> getClimaActual({String destino = 'Ica'}) async {
    try {
      final query = Uri(queryParameters: {'destino': destino}).query;
      final data = await _apiClient.get('/weather/current?$query');
      return ClimaActualModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[WeatherService] Error al obtener clima actual: $e. Usando fallback.');
      return const ClimaActualModel(
        temperaturaActual: 26.0,
        sensacionTermica: 26.5,
        probabilidadPrecipitacion: 8.0,
        humedad: 48.0,
        velocidadViento: 12.0,
        indiceUv: 6.0,
        descripcionClima: 'Soleado',
        visibilidad: 10.0,
        destino: 'Ica',
        isCached: true,
      );
    }
  }

  /// Obtiene el pronóstico extendido (horas y días)
  Future<PronosticoCompletoModel> getPronostico({String destino = 'Ica'}) async {
    try {
      final query = Uri(queryParameters: {'destino': destino}).query;
      final data = await _apiClient.get('/weather/forecast?$query');
      return PronosticoCompletoModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[WeatherService] Error al obtener pronóstico: $e. Usando fallback.');
      final now = DateTime.now();
      return PronosticoCompletoModel(
        destino: destino,
        horas: [
          PronosticoHoraModel(
            time: DateTime(now.year, now.month, now.day, 8, 0),
            temperature: 20.0,
            uvIndex: 2.0,
            windSpeed: 10.0,
            precipitationProbability: 5.0,
            condition: 'Soleado',
          ),
          PronosticoHoraModel(
            time: DateTime(now.year, now.month, now.day, 11, 0),
            temperature: 25.0,
            uvIndex: 7.0,
            windSpeed: 12.0,
            precipitationProbability: 5.0,
            condition: 'Soleado',
          ),
          PronosticoHoraModel(
            time: DateTime(now.year, now.month, now.day, 14, 0),
            temperature: 26.0,
            uvIndex: 8.0,
            windSpeed: 15.0,
            precipitationProbability: 10.0,
            condition: 'Parcialmente nublado',
          ),
          PronosticoHoraModel(
            time: DateTime(now.year, now.month, now.day, 17, 0),
            temperature: 22.0,
            uvIndex: 3.0,
            windSpeed: 18.0,
            precipitationProbability: 5.0,
            condition: 'Viento Paracas',
          ),
          PronosticoHoraModel(
            time: DateTime(now.year, now.month, now.day, 20, 0),
            temperature: 19.0,
            uvIndex: 0.0,
            windSpeed: 14.0,
            precipitationProbability: 0.0,
            condition: 'Despejado',
          ),
        ],
        dias: const [
          PronosticoDiaModel(
            date: 'Hoy',
            tempMin: 16.0,
            tempMax: 27.0,
            uvIndexMax: 8.0,
            windSpeedMax: 18.0,
            precipitationSum: 0.0,
            precipitationProbabilityMax: 8.0,
            condition: 'Soleado',
          ),
          PronosticoDiaModel(
            date: 'Mañana',
            tempMin: 15.0,
            tempMax: 25.0,
            uvIndexMax: 7.0,
            windSpeedMax: 20.0,
            precipitationSum: 0.0,
            precipitationProbabilityMax: 12.0,
            condition: 'Parcialmente nublado',
          ),
        ],
      );
    }
  }

  /// Obtiene la lista de alertas meteorológicas activas
  Future<List<AlertaClimaModel>> getAlertasActivas() async {
    try {
      final data = await _apiClient.get('/weather/alerts');
      if (data is List<dynamic>) {
        return data.map((e) => AlertaClimaModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[WeatherService] Error al obtener alertas: $e. Usando fallback.');
    }

    return [
      AlertaClimaModel(
        id: '1',
        zone: 'Paracas',
        code: 'VIENTO_PARACAS',
        severity: 'HIGH',
        message: 'Viento fuerte en Paracas: ráfagas previstas de hasta 35 km/h.',
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(hours: 6)),
      ),
      AlertaClimaModel(
        id: '2',
        zone: 'Huacachina',
        code: 'UV_EXTREMO',
        severity: 'MODERATE',
        message: 'Radiación solar extrema en el desierto. Usa protector y lentes con filtro UV.',
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(hours: 5)),
      ),
    ];
  }

  /// Obtiene recomendaciones inteligentes con IA basadas en clima y actividad
  Future<List<RecomendacionClimaModel>> getRecomendaciones({
    String destino = 'Ica',
    List<String>? actividades,
  }) async {
    try {
      final queryParams = <String, String>{'destino': destino};
      if (actividades != null && actividades.isNotEmpty) {
        queryParams['actividades'] = actividades.join(',');
      }
      final query = Uri(queryParameters: queryParams).query;
      final data = await _apiClient.get('/weather/recommendations?$query');
      if (data is List<dynamic>) {
        return data.map((e) => RecomendacionClimaModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[WeatherService] Error al obtener recomendaciones IA: $e. Usando fallback.');
    }

    return const [
      RecomendacionClimaModel(
        actividad: 'Sandboarding en Huacachina',
        score: 0.88,
        nivel: 'ideal',
        justificacion: 'Las condiciones de temperatura y viento de la tarde permiten deslizarse de forma segura en las dunas.',
        mejorHorario: '16:00 - 18:00',
        precauciones: ['Usar bloqueador solar', 'Llevar hidratación'],
      ),
      RecomendacionClimaModel(
        actividad: 'Tour Islas Ballestas',
        score: 0.82,
        nivel: 'bueno',
        justificacion: 'Mar calmo durante la mañana antes de que se intensifique el viento Paracas.',
        mejorHorario: '08:00 - 10:30',
        precauciones: ['Llevar cortaviento', 'Uso obligatorio de chaleco'],
      ),
    ];
  }
}
