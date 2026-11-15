// Guard de regresión de desbordes de layout (RenderFlex overflow).
// Renderiza cada pantalla al tamaño físico del teléfono real de pruebas
// (Xiaomi 2510DRA23L: 1080x2392 @ densidad 2.625 => 411.4 x 911.2 lógicos)
// y falla si alguna produce "A RenderFlex overflowed" de 1 px o más.
//
// Se revisa dos veces: con la letra del sistema normal y con la letra grande
// (145 %, que es como viene configurado el teléfono de pruebas). El segundo
// caso es el que destapó los botones desbordados de "Cuéntanos tus gustos".
//
// Ejecutar:  flutter test test/overflow_scan_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ika_travel_mobile/config/escala_texto.dart';
import 'package:ika_travel_mobile/data/lugares_mock.dart';
import 'package:ika_travel_mobile/screens/pantalla_inicio.dart';
import 'package:ika_travel_mobile/screens/pantalla_actividades.dart';
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
import 'package:ika_travel_mobile/models/usuario_modelo.dart';
import 'package:ika_travel_mobile/services/alertas_service.dart';
import 'package:ika_travel_mobile/services/auth_service.dart';
import 'package:ika_travel_mobile/services/sos_service.dart';
import 'package:ika_travel_mobile/widgets/modal_preferencias.dart';

Map<String, Widget> construirPantallas() => <String, Widget>{
      'Inicio': const PantallaInicio(),
      'Actividades': PantallaActividades(onVolverInicio: () {}),
      // 'Mapa' se omite: flutter_map deja un timer interno que ensucia el test
      // y su layout no desborda (solo un sub-pixel por redondeo).
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
      'Detalle': PantallaDetalle(lugar: LugaresMock.lugares.first),
      'DetalleDia': const PantallaDetalleDia(
        tituloActividad: 'Clima en Ica hoy',
        imagenActividad: 'assets/images/carrusel_1_huacachina.jpg',
      ),
    };

/// Captura los desbordes de layout que ocurran mientras corre [accion].
///
/// Cualquier otro error (red, canales nativos, assets, timers) se ignora: no
/// es el objeto de este guard.
Future<List<String>> _capturarDesbordes(
  Future<void> Function(List<String> hallazgos) accion,
) async {
  final hallazgos = <String>[];
  final anterior = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) {
    final s = d.exceptionAsString();
    if (!s.contains('overflowed')) return;
    final px = RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(s);
    if (px != null && (double.tryParse(px.group(1)!) ?? 1) < 1) return;
    final m = RegExp(r'(pantalla|modal|dialogo)_[a-z_]+\.dart:\d+:\d+')
        .firstMatch(d.toString());
    hallazgos.add('${s.split('\n').first}  →  ${m?.group(0) ?? '¿ubicación?'}');
  };

  try {
    await accion(hallazgos);
  } finally {
    FlutterError.onError = anterior;
  }
  return hallazgos;
}

/// Envuelve la pantalla igual que lo hace la app real, con el mismo tope de
/// escala de letra. Si el test no lo aplicara, estaría midiendo una app que
/// no existe.
Widget _comoEnLaApp(Widget pantalla) => MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: EscalaTexto.aplicar,
      home: pantalla,
    );

void _reportar(String titulo, List<String> hallazgos) {
  // ignore: avoid_print
  print('\n===== $titulo =====\n'
      '${hallazgos.isEmpty ? 'Sin desbordes ≥ 1 px.' : hallazgos.join('\n')}\n'
      '================================\n');
}

void main() {
  for (final escala in <double>[1.0, 1.45]) {
    final etiqueta = escala == 1.0 ? 'letra normal' : 'letra al 145%';

    testWidgets('ninguna pantalla desborda a 411x911 con $etiqueta',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2392);
      tester.view.devicePixelRatio = 2.625;
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final hallazgos = await _capturarDesbordes((hallazgos) async {
        try {
          for (final entry in construirPantallas().entries) {
            final antes = hallazgos.length;
            await tester.pumpWidget(_comoEnLaApp(entry.value));
            await tester.pump(const Duration(milliseconds: 50));
            // Sustituir la pantalla dispara su dispose() y cancela sus timers,
            // evitando el fallo por "timer pendiente".
            await tester.pumpWidget(const SizedBox.shrink());
            for (var i = antes; i < hallazgos.length; i++) {
              hallazgos[i] = '• ${entry.key}: ${hallazgos[i]}';
            }
          }
        } finally {
          // El singleton de alertas arranca un timer de refresco de 5 min; se
          // cancela aquí para que el test no falle por "timer pendiente".
          AlertasService().dispose();
        }
      });

      _reportar('ESCANEO DE DESBORDES ($etiqueta)', hallazgos);
      expect(hallazgos, isEmpty, reason: hallazgos.join('\n'));
    });
  }

  testWidgets('el modal "Cuéntanos tus gustos" no desborda con letra al 145%',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2392);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.45;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final hallazgos = await _capturarDesbordes((_) async {
      await tester.pumpWidget(_comoEnLaApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => ModalPreferencias.mostrar(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // Con los 8 gustos visibles: es el estado con más texto en pantalla.
      expect(find.text('Cuéntanos tus gustos'), findsOneWidget);
      expect(find.text('Guardar preferencias'), findsOneWidget);
      expect(find.text('Omitir por ahora'), findsOneWidget);

      // Y con un gusto elegido, que es cuando el botón principal se activa.
      await tester.tap(find.text('Aventura y adrenalina'));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    _reportar('MODAL DE PREFERENCIAS (letra al 145%)', hallazgos);
    expect(hallazgos, isEmpty, reason: hallazgos.join('\n'));
  });

  testWidgets('la hoja de opciones manuales del SOS no desborda con letra al 145%',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2392);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.45;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // La hoja solo se abre con sesión iniciada y un contacto de confianza
    // registrado; si falta alguno, sale un diálogo distinto.
    final auth = AuthService();
    final usuarioPrevio = auth.usuarioNotifier.value;
    auth.usuarioNotifier.value = UsuarioModelo.demo();
    final sos = SosService();
    // Sin esto, la hoja se queda esperando una lectura de GPS que en un test
    // nunca llega (no hay canal nativo) y nunca llega a mostrarse.
    sos.permisoUbicacionConcedido.value = false;
    sos.guardarContacto(
      nombre: 'María Gómez',
      telefono: '+51 987654321',
      relacion: 'Hermana',
    );
    addTearDown(() {
      auth.usuarioNotifier.value = usuarioPrevio;
      while (sos.contactos.isNotEmpty) {
        sos.eliminarContacto(0);
      }
      AlertasService().dispose();
    });

    final hallazgos = await _capturarDesbordes((_) async {
      await tester.pumpWidget(_comoEnLaApp(const PantallaSos()));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Opciones manuales'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Es la hoja con los botones de despacho, la que se veía desbordada.
      expect(find.text('Enviar ahora por WhatsApp y SMS'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    _reportar('HOJA DE OPCIONES SOS (letra al 145%)', hallazgos);
    expect(hallazgos, isEmpty, reason: hallazgos.join('\n'));
  });
}
