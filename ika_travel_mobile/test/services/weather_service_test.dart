import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ika_travel_mobile/services/api_client.dart';
import 'package:ika_travel_mobile/services/weather_service.dart';

void main() {
  group('WeatherService', () {
    test('getClimaActual parsea respuesta exitosa del backend', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/weather/current')) {
          final payload = {
            'temperatura_actual': 28.5,
            'sensacion_termica': 29.0,
            'probabilidad_precipitacion': 0.0,
            'humedad': 42.0,
            'velocidad_viento': 14.5,
            'indice_uv': 9.2,
            'descripcion_clima': 'Cielo despejado con sol radiante',
            'visibilidad': 10.0,
            'destino': 'Ica',
            'is_cached': false,
          };
          return http.Response(json.encode(payload), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final service = WeatherService(apiClient: apiClient);

      final clima = await service.getClimaActual(destino: 'Ica');

      expect(clima.temperaturaActual, 28.5);
      expect(clima.nivelUv, 'Muy Alto');
      expect(clima.descripcionClima, 'Cielo despejado con sol radiante');
      expect(clima.isCached, false);
    });

    test('getClimaActual usa fallback estructurado ante error 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final apiClient = ApiClient(client: mockClient);
      final service = WeatherService(apiClient: apiClient);

      final clima = await service.getClimaActual(destino: 'Ica');

      expect(clima.temperaturaActual, 26.0);
      expect(clima.isCached, true);
    });

    test('getPronostico parsea horas y dias correctamente', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/weather/forecast')) {
          final payload = {
            'destino': 'Ica',
            'horas': [
              {
                'time': '2026-10-17T12:00:00Z',
                'temperature': 27.0,
                'uv_index': 8.5,
                'wind_speed': 16.0,
                'precipitation_probability': 0.0,
                'condition': 'Soleado',
              }
            ],
            'dias': [
              {
                'date': '2026-10-17',
                'temp_min': 15.0,
                'temp_max': 28.0,
                'uv_index_max': 9.0,
                'wind_speed_max': 18.0,
                'precipitation_sum': 0.0,
                'precipitation_probability_max': 5.0,
                'condition': 'Soleado',
              }
            ]
          };
          return http.Response(json.encode(payload), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final service = WeatherService(apiClient: apiClient);

      final pronostico = await service.getPronostico(destino: 'Ica');

      expect(pronostico.destino, 'Ica');
      expect(pronostico.horas.length, 1);
      expect(pronostico.horas.first.temperature, 27.0);
      expect(pronostico.dias.length, 1);
      expect(pronostico.dias.first.tempMax, 28.0);
    });
  });
}
