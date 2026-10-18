import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ika_travel_mobile/screens/pantalla_alertas.dart';
import 'package:ika_travel_mobile/services/api_client.dart';
import 'package:ika_travel_mobile/services/weather_service.dart';

void main() {
  testWidgets('PantallaAlertas muestra alertas reales del backend', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/weather/alerts')) {
        final payload = [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'zone': 'Paracas',
            'code': 'VIENTO_PARACAS',
            'severity': 'HIGH',
            'message': 'Ráfagas de viento mayores a 40 km/h en zona costera.',
            'starts_at': '2026-10-17T12:00:00Z',
            'ends_at': '2026-10-17T20:00:00Z',
          }
        ];
        return http.Response(json.encode(payload), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient);
    final weatherService = WeatherService(apiClient: apiClient);

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaAlertas(weatherService: weatherService),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Alertas Climáticas'), findsOneWidget);
    expect(find.text('Zona: Paracas'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('Ráfagas de viento mayores a 40 km/h en zona costera.'), findsOneWidget);
  });
}
