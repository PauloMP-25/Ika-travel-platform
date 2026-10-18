import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ika_travel_mobile/main.dart';

void main() {
  testWidgets('App arranca correctamente', (WidgetTester tester) async {
    // Construimos la app y esperamos a que se dibuje
    await tester.pumpWidget(const IkaTravelApp());

    // Verificamos que la app se haya construido correctamente
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
