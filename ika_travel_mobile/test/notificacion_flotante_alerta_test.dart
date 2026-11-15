import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ika_travel_mobile/config/navegacion_service.dart';
import 'package:ika_travel_mobile/models/alerta_modelo.dart';
import 'package:ika_travel_mobile/screens/pantalla_detalle_alerta.dart';
import 'package:ika_travel_mobile/widgets/notificacion_flotante_alerta.dart';

void main() {
  testWidgets('NotificacionFlotanteAlerta despliega banner estilo WhatsApp y navega al detalle al pulsar',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final alertaPrueba = AlertaClima(
      id: 'alerta-test-paracas-1',
      titulo: 'Vientos Fuertes Paracas',
      destino: 'Paracas',
      actividad: 'Reserva Nacional de Paracas',
      fechaHora: now,
      nivelRiesgo: NivelRiesgo.alto,
      motivoCambio: 'Ráfagas de 48 km/h en la costa de la Reserva.',
      impactoActividad: 'Restricción de embarcaciones y precaución en desierto.',
      condicionAnterior: CondicionClima(
        fechaHora: now,
        estadoCielo: 'Despejado',
        temperatura: '23°C',
        velocidadViento: '15 km/h',
        probabilidadLluvia: '0%',
        indiceUv: '7.0',
        estadoMar: 'Calmo',
      ),
      condicionActual: CondicionClima(
        fechaHora: now,
        estadoCielo: 'Ventoso',
        temperatura: '21°C',
        velocidadViento: '48 km/h',
        probabilidadLluvia: '0%',
        indiceUv: '7.0',
        estadoMar: 'Picado',
      ),
      recomendacionesSeguridad: ['Llevar protección ocular y evitar acantilados.'],
      esMock: false,
      activa: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: NavegacionService.navigatorKey,
        home: const Scaffold(
          body: Center(child: Text('Pantalla Principal')),
        ),
      ),
    );

    expect(find.text('Pantalla Principal'), findsOneWidget);
    expect(find.text('Vientos Fuertes Paracas'), findsNothing);

    // 1. Mostrar la notificación flotante
    NotificacionFlotanteAlerta.mostrar(alerta: alertaPrueba);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 2. Verificar que se renderiza el banner flotante con datos de Paracas
    expect(find.text('IKA TRAVEL • ALERTA PARACAS'), findsOneWidget);
    expect(find.text('Vientos Fuertes Paracas'), findsOneWidget);
    expect(find.text('Ráfagas de 48 km/h en la costa de la Reserva.'), findsOneWidget);
    expect(find.text('AHORA'), findsOneWidget);

    // 3. Tocar el banner flotante
    await tester.tap(find.text('Vientos Fuertes Paracas'));
    await tester.pumpAndSettle();

    // 4. Verificar que navegó a PantallaDetalleAlerta
    expect(find.byType(PantallaDetalleAlerta), findsOneWidget);
  });
}
