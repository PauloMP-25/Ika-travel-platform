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
}
