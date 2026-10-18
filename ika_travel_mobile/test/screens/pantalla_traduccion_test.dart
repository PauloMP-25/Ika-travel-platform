import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ika_travel_mobile/screens/pantalla_traduccion.dart';
import 'package:ika_travel_mobile/services/api_client.dart';
import 'package:ika_travel_mobile/services/translation_service.dart';

void main() {
  testWidgets('PantallaTraduccion carga y renderiza frases del frasebook', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/translation/phrases')) {
        final payload = {
          'total': 1,
          'version': 'v1-test',
          'phrases': [
            {
              'id': '1',
              'category': 'emergency',
              'spanish': '¿Dónde está la policía?',
              'english': 'Where is the police station?',
            }
          ]
        };
        return http.Response(json.encode(payload), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient);
    final service = TranslationService(apiClient: apiClient);

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaTraduccion(translationService: service),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('¿Dónde está la policía?'), findsOneWidget);
    expect(find.text('Where is the police station?'), findsOneWidget);
  });
}
