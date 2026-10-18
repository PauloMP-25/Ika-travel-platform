import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ika_travel_mobile/screens/pantalla_inicio.dart';
import 'package:ika_travel_mobile/services/api_client.dart';
import 'package:ika_travel_mobile/services/weather_service.dart';

void main() {
  testWidgets('PantallaInicio muestra datos de clima en vivo', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/weather/current')) {
        final payload = {
          'temperatura_actual': 31.0,
          'sensacion_termica': 32.0,
          'probabilidad_precipitacion': 0.0,
          'humedad': 38.0,
          'velocidad_viento': 22.0,
          'indice_uv': 11.0,
          'descripcion_clima': 'Sol radiante',
          'visibilidad': 10.0,
          'destino': 'Ica',
          'is_cached': false,
        };
        return http.Response(json.encode(payload), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient);
    final weatherService = WeatherService(apiClient: apiClient);

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaInicio(weatherService: weatherService),
      ),
    );

    // Permitir resolución de Future
    await tester.pumpAndSettle();

    expect(find.text('Ahora en Ica'), findsOneWidget);
    expect(find.text('31°C'), findsOneWidget);
    expect(find.text('Viento   22 km/h'), findsOneWidget);
    expect(find.text('Humedad  38%'), findsOneWidget);
    expect(find.text('UV        Extremo'), findsOneWidget);
  });
}
