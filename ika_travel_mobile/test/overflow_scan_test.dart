// Guard de regresión de desbordes de layout (RenderFlex overflow).
// Renderiza cada pantalla al tamaño físico del teléfono real de pruebas
// (Xiaomi 2510DRA23L: 1080x2392 @ densidad 2.625 => 411.4 x 911.2 lógicos)
// y falla si alguna produce "A RenderFlex overflowed" de 1 px o más.
//
// Ejecutar:  flutter test test/overflow_scan_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ika_travel_mobile/screens/pantalla_inicio.dart';
import 'package:ika_travel_mobile/screens/pantalla_actividades.dart';
import 'package:ika_travel_mobile/screens/pantalla_mapa.dart';
import 'package:ika_travel_mobile/screens/pantalla_pronostico.dart';
import 'package:ika_travel_mobile/screens/pantalla_favoritos.dart';
import 'package:ika_travel_mobile/screens/pantalla_sos.dart';
import 'package:ika_travel_mobile/screens/pantalla_traduccion.dart';
import 'package:ika_travel_mobile/screens/pantalla_prestadores.dart';
import 'package:ika_travel_mobile/screens/pantalla_reporte_incidencia.dart';
import 'package:ika_travel_mobile/screens/pantalla_alertas.dart';
import 'package:ika_travel_mobile/screens/pantalla_configurar_alertas.dart';
import 'package:ika_travel_mobile/screens/pantalla_mas.dart';
import 'package:ika_travel_mobile/screens/pantalla_detalle.dart';
import 'package:ika_travel_mobile/screens/pantalla_detalle_dia.dart';
import 'package:ika_travel_mobile/screens/pantalla_configuracion.dart';
import 'package:ika_travel_mobile/services/alertas_service.dart';

final pantallas = <String, Widget>{
  'Inicio': const PantallaInicio(),
  'Actividades': PantallaActividades(onVolverInicio: () {}),
  // 'Mapa' se omite: flutter_map deja un timer interno que ensucia el test y
  // su layout no desborda (solo un sub-pixel por redondeo).
  'Pronostico': const PantallaPronostico(),
  'Favoritos': const PantallaFavoritos(),
  'SOS': const PantallaSos(),
  'Traduccion': const PantallaTraduccion(),
  'Prestadores': const PantallaPrestadores(),
  'ReporteIncidencia': const PantallaReporteIncidencia(),
  'Alertas': const PantallaAlertas(),
  'ConfigurarAlertas': const PantallaConfigurarAlertas(),
  'Mas': const PantallaMas(),
  'Configuracion': const PantallaConfiguracion(),
  'Detalle': const PantallaDetalle(
    titulo: 'Oasis de Huacachina',
    subtitulo: 'Ica',
    imagenes: ['assets/images/carrusel_1_huacachina.jpg'],
  ),
  'DetalleDia': const PantallaDetalleDia(
    tituloActividad: 'Clima en Ica hoy',
    imagenActividad: 'assets/images/carrusel_1_huacachina.jpg',
  ),
};

void main() {
  testWidgets('ninguna pantalla desborda a 411x911 (teléfono de pruebas)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2392);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final hallazgos = <String>[];
    // Solo desbordes de layout; cualquier otro error (red, canales nativos,
    // assets, timers) se ignora: no es el objeto de este guard.
    final anterior = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      final s = d.exceptionAsString();
      if (!s.contains('overflowed')) return;
      final px = RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(s);
      if (px != null && (double.tryParse(px.group(1)!) ?? 1) < 1) return;
      final m = RegExp(r'pantalla_[a-z_]+\.dart:\d+:\d+').firstMatch(d.toString());
      hallazgos.add('${s.split('\n').first}  →  ${m?.group(0) ?? '¿ubicación?'}');
    };

    try {
      for (final entry in pantallas.entries) {
        final antes = hallazgos.length;
        await tester.pumpWidget(MaterialApp(
          home: entry.value,
          debugShowCheckedModeBanner: false,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        // Sustituir la pantalla dispara su dispose() y cancela sus timers,
        // evitando el fallo por "timer pendiente".
        await tester.pumpWidget(const SizedBox.shrink());
        for (var i = antes; i < hallazgos.length; i++) {
          hallazgos[i] = '• ${entry.key}: ${hallazgos[i]}';
        }
      }
    } finally {
      FlutterError.onError = anterior;
      // El singleton de alertas arranca un timer de refresco de 5 min; se
      // cancela aquí para que el test no falle por "timer pendiente".
      AlertasService().dispose();
    }

    // ignore: avoid_print
    print('\n===== ESCANEO DE DESBORDES =====\n'
        '${hallazgos.isEmpty ? 'Sin desbordes ≥ 1 px.' : hallazgos.join('\n')}\n'
        '================================\n');
    expect(hallazgos, isEmpty, reason: hallazgos.join('\n'));
  });
}
