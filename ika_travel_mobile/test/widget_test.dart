import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ika_travel_mobile/main.dart';

void main() {
  testWidgets('App arranca correctamente y renderiza el árbol principal', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('ClientException') ||
          details.exceptionAsString().contains('openstreetmap')) {
        return;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(const IkaTravelApp());
    expect(find.byType(MaterialApp), findsOneWidget);

    FlutterError.onError = originalOnError;
  });
}
