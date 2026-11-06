import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ika_travel_mobile/models/alerta_modelo.dart';
import 'package:ika_travel_mobile/models/alternativa_modelo.dart';
import 'package:ika_travel_mobile/models/horario_modelo.dart';
import 'package:ika_travel_mobile/models/seguimiento_modelo.dart';
import 'package:ika_travel_mobile/services/alertas_service.dart';
import 'package:ika_travel_mobile/services/recomendador_service.dart';
import 'package:ika_travel_mobile/services/seguimiento_service.dart';
import 'package:ika_travel_mobile/services/sos_service.dart';
import 'package:ika_travel_mobile/config/navegacion_service.dart';
import 'package:ika_travel_mobile/screens/pantalla_detalle_alerta.dart';
import 'package:ika_travel_mobile/screens/pantalla_detalle_alternativa.dart';
import 'package:ika_travel_mobile/screens/pantalla_seguimiento_destino.dart';
import 'package:ika_travel_mobile/screens/pantalla_sos.dart';
import 'package:ika_travel_mobile/widgets/tarjeta_horarios_atencion.dart';

void main() {
  group('Requerimiento 11: Alerta Automática y Detección de Cambios', () {
    final service = AlertasService();

    test('El servicio inicia vacío (sin mocks, todo viene del backend)', () {
      // Ahora el servicio arranca con lista vacía hasta que el backend responda.
      expect(service.todasLasAlertas, isEmpty);
      expect(service.alertasActivas, isEmpty);
      expect(service.historialAlertas, isEmpty);
    });

    test('Destinos por defecto para seguimiento', () {
      expect(
        service.destinosSeguidosNotifier.value.contains('Huacachina'),
        isTrue,
      );
      expect(
        service.destinosSeguidosNotifier.value.contains('Paracas'),
        isTrue,
      );
      expect(service.destinosSeguidosNotifier.value.contains('Ica'), isTrue);
    });

    test('Permite seguir y dejar de seguir un destino', () {
      final destinoPrueba = 'Nazca';
      expect(service.estaSiguiendoDestino(destinoPrueba), isFalse);

      service.toggleSeguirDestino(destinoPrueba);
      expect(service.estaSiguiendoDestino(destinoPrueba), isTrue);

      service.toggleSeguirDestino(destinoPrueba);
      expect(service.estaSiguiendoDestino(destinoPrueba), isFalse);
    });

    test('Gestión de configuración y permisos de notificación', () {
      final config = service.configNotifier.value;
      expect(config.permisosConcedidos, isTrue);

      service.actualizarConfiguracion(
        ConfiguracionNotificaciones(
          permisosConcedidos: false,
          pushHabilitado: false,
          alertarViento: true,
          alertarOleaje: false,
          alertarUv: true,
          alertarLluvia: false,
        ),
      );

      final nuevaConfig = service.configNotifier.value;
      expect(nuevaConfig.permisosConcedidos, isFalse);
      expect(nuevaConfig.alertarOleaje, isFalse);
    });
  });

  group('Requerimiento 12: ¿Por qué cambió? y Modelo de Alerta', () {
    test(
      'Serialización y deserialización JSON de AlertaClima y CondicionClima',
      () {
        final alerta = AlertaClima(
          id: 'json_test_01',
          titulo: 'Viento en Paracas',
          destino: 'Paracas',
          actividad: 'Paseo en lancha',
          fechaHora: DateTime.parse('2026-10-18T14:30:00Z'),
          nivelRiesgo: NivelRiesgo.precaucion,
          motivoCambio: 'Incremento de brisa térmica',
          impactoActividad: 'Oleaje moderado',
          condicionAnterior: CondicionClima(
            fechaHora: DateTime.parse('2026-10-18T11:00:00Z'),
            estadoCielo: 'Calmado',
            temperatura: '20°C',
            velocidadViento: '10 km/h',
            probabilidadLluvia: '0%',
            indiceUv: 'Moderado',
          ),
          condicionActual: CondicionClima(
            fechaHora: DateTime.parse('2026-10-18T14:30:00Z'),
            estadoCielo: 'Ventoso',
            temperatura: '22°C',
            velocidadViento: '26 km/h',
            probabilidadLluvia: '0%',
            indiceUv: 'Alto',
          ),
          recomendacionesSeguridad: [
            'Llevar chaleco salvavidas',
            'Ropa abrigada',
          ],
          esMock: false,
        );

        final json = alerta.toJson();
        final reconstruida = AlertaClima.fromJson(json);

        expect(reconstruida.id, equals('json_test_01'));
        expect(reconstruida.nivelRiesgo, equals(NivelRiesgo.precaucion));
        expect(
          reconstruida.condicionAnterior.velocidadViento,
          equals('10 km/h'),
        );
        expect(reconstruida.condicionActual.velocidadViento, equals('26 km/h'));
        expect(reconstruida.recomendacionesSeguridad.length, equals(2));
      },
    );

    testWidgets(
      'PantallaDetalleAlerta muestra motivo, comparativa antes/después y recomendaciones',
      (WidgetTester tester) async {
        // Creamos una alerta de prueba manualmente (sin mocks del servicio)
        final alertaPrueba = AlertaClima(
          id: 'test_detalle_01',
          titulo: 'Radiación UV extrema',
          destino: 'Ica',
          actividad: 'Actividades al aire libre',
          fechaHora: DateTime.now(),
          nivelRiesgo: NivelRiesgo.precaucion,
          motivoCambio: 'Radiación UV Alta (9): protección solar recomendada.',
          impactoActividad: '',
          condicionAnterior: CondicionClima(
            fechaHora: DateTime.now(),
            estadoCielo: '--',
            temperatura: '--',
            velocidadViento: '--',
            probabilidadLluvia: '--',
            indiceUv: '--',
          ),
          condicionActual: CondicionClima(
            fechaHora: DateTime.now(),
            estadoCielo: '--',
            temperatura: '--',
            velocidadViento: '--',
            probabilidadLluvia: '--',
            indiceUv: '--',
          ),
          recomendacionesSeguridad: const [
            'Usar protector solar SPF 50+.',
            'Llevar sombrero de ala ancha.',
          ],
          esMock: false,
        );

        await tester.pumpWidget(
          MaterialApp(home: PantallaDetalleAlerta(alerta: alertaPrueba)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Detalle de la Alerta'), findsOneWidget);
        expect(find.text('¿Por qué cambió?'), findsOneWidget);
        expect(
          find.text('Recomendaciones prácticas de seguridad'),
          findsOneWidget,
        );
      },
    );
  });

  group('Requerimiento 13: Alternativa Recomendada', () {
    final recomendador = RecomendadorService();

    test(
      'Recomienda viñedos y mejores horarios ante viento fuerte en Huacachina',
      () {
        // Crear alerta manualmente (no usar mocks del servicio)
        final alertaHuacachina = AlertaClima(
          id: 'test_huacachina',
          titulo: 'Viento en Huacachina',
          destino: 'Huacachina',
          actividad: 'Sandboarding',
          fechaHora: DateTime.now(),
          nivelRiesgo: NivelRiesgo.alto,
          motivoCambio: 'Viento fuerte',
          impactoActividad: 'Riesgo en dunas',
          condicionAnterior: CondicionClima(
            fechaHora: DateTime.now().subtract(const Duration(hours: 3)),
            estadoCielo: 'Despejado',
            temperatura: '25°C',
            velocidadViento: '14 km/h',
            probabilidadLluvia: '0%',
            indiceUv: 'Alto',
          ),
          condicionActual: CondicionClima(
            fechaHora: DateTime.now(),
            estadoCielo: 'Polvareda',
            temperatura: '28°C',
            velocidadViento: '34 km/h',
            probabilidadLluvia: '0%',
            indiceUv: 'Alto',
          ),
          recomendacionesSeguridad: const ['Usar gafas antipolvo.'],
          esMock: false,
        );

        final alternativas = recomendador.obtenerAlternativasParaAlerta(
          alertaHuacachina,
        );
        expect(alternativas.isNotEmpty, isTrue);

        final tieneVinos = alternativas.any(
          (a) => a.tituloActividad.contains('Viñedos'),
        );
        final tieneMejorHorario = alternativas.any(
          (a) => a.mejorHorarioSugerido != null,
        );

        expect(tieneVinos, isTrue);
        expect(tieneMejorHorario, isTrue);
      },
    );

    test('Recomienda circuito terrestre ante oleaje en Islas Ballestas', () {
      final alertaBallestas = AlertaClima(
        id: 'test_ballestas',
        titulo: 'Oleaje alto en Paracas',
        destino: 'Paracas',
        actividad: 'Islas Ballestas',
        fechaHora: DateTime.now(),
        nivelRiesgo: NivelRiesgo.critico,
        motivoCambio: 'Mar picado',
        impactoActividad: 'Restricción de zarpe',
        condicionAnterior: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(hours: 4)),
          estadoCielo: 'Calmado',
          temperatura: '21°C',
          velocidadViento: '10 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Moderado',
        ),
        condicionActual: CondicionClima(
          fechaHora: DateTime.now(),
          estadoCielo: 'Mar picado',
          temperatura: '19°C',
          velocidadViento: '28 km/h',
          probabilidadLluvia: '10%',
          indiceUv: 'Bajo',
        ),
        recomendacionesSeguridad: const ['Usar chaleco salvavidas.'],
        esMock: false,
      );

      final alternativas = recomendador.obtenerAlternativasParaAlerta(
        alertaBallestas,
      );
      expect(alternativas.isNotEmpty, isTrue);
      final tieneReserva = alternativas.any(
        (a) => a.tituloActividad.contains('Reserva Nacional'),
      );
      expect(tieneReserva, isTrue);
    });
  });

  group('Requerimiento 14: Seguimiento del Destino', () {
    final seguimientoService = SeguimientoService();

    test('Destinos disponen de estado actual, historial cronológico y aptitud de actividades', () {
      final destinos = seguimientoService.destinosNotifier.value;
      expect(destinos.isNotEmpty, isTrue);

      final huacachina = seguimientoService.obtenerPorNombre('Huacachina');
      expect(huacachina, isNotNull);
      expect(huacachina!.estadoGeneral.isNotEmpty, isTrue);
      expect(huacachina.actividadesAptitud.isNotEmpty, isTrue);
      expect(huacachina.historialCambios.isNotEmpty, isTrue);

      final primerCambio = huacachina.historialCambios.first;
      expect(primerCambio.valorAnterior.isNotEmpty, isTrue);
      expect(primerCambio.valorActual.isNotEmpty, isTrue);
      expect(primerCambio.parametroModificado.isNotEmpty, isTrue);
    });

    test('Serialización JSON de DestinoSeguimiento', () {
      final destino = seguimientoService.destinosNotifier.value.first;
      final json = destino.toJson();
      final reconstruido = DestinoSeguimiento.fromJson(json);

      expect(reconstruido.id, equals(destino.id));
      expect(reconstruido.nombre, equals(destino.nombre));
      expect(
        reconstruido.historialCambios.length,
        equals(destino.historialCambios.length),
      );
    });

    testWidgets(
      'PantallaSeguimientoDestino renderiza pestañas, aptitud e historial',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PantallaSeguimientoDestino(
              nombreDestinoInicial: 'Huacachina',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Seguimiento del Destino'), findsOneWidget);
        expect(
          find.text('Condiciones para actividades disponibles'),
          findsOneWidget,
        );
        expect(find.text('Historial cronológico de cambios'), findsOneWidget);
        expect(
          find.text('Alertas relacionadas con el destino'),
          findsOneWidget,
        );
      },
    );
  });

  group('Mejoras: Horarios de Atención en Información de Destinos', () {
    test(
      'HorarioAtencion soporta estado de verificación y días diferenciados',
      () {
        final horarioVerificado = HorarioAtencion.paraReservaParacas();

        expect(
          horarioVerificado.estadoVerificacion,
          equals('Horario verificado SERNANP'),
        );
        expect(horarioVerificado.esVerificado, isTrue);
        expect(horarioVerificado.horariosPorDia.length, equals(2));

        final horarioReferencial = HorarioAtencion.paraHuacachina();
        expect(
          horarioReferencial.estadoVerificacion,
          equals('Horario referencial'),
        );

        final horarioNoConfirmado = HorarioAtencion.noConfirmado();
        expect(
          horarioNoConfirmado.estadoVerificacion,
          equals('Horario no confirmado'),
        );
      },
    );

    testWidgets('TarjetaHorariosAtencion muestra días, badge y observaciones', (
      WidgetTester tester,
    ) async {
      final horario = HorarioAtencion.paraVinedos();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TarjetaHorariosAtencion(
              horario: horario,
              tituloDestino: 'Ruta de Viñedos',
            ),
          ),
        ),
      );

      expect(find.text('Horarios de Atención'), findsOneWidget);
      expect(find.text('Martes a Domingo'), findsOneWidget);
      expect(find.text('09:00 - 17:30 hrs'), findsOneWidget);
      expect(find.text('Horario referencial'), findsOneWidget);
    });
  });

  group('Mejoras: Pantalla Independiente de Alternativa Recomendada', () {
    testWidgets(
      'PantallaDetalleAlternativa renderiza información completa y acciones',
      (WidgetTester tester) async {
        final alternativa = AlternativaRecomendada(
          id: 'alt_test_01',
          tituloActividad: 'Ruta del Pisco y Viñedos Tradicionales',
          descripcionLugar:
              'Bodegas históricas resguardadas del viento en el valle.',
          destino: 'Ica',
          imagen: 'assets/images/carrusel_2_vinos.jpg',
          tipoAlternativa: TipoAlternativa.otroDestinoCercano,
          temperaturaActual: '26°C',
          vientoActual: '12 km/h (Calmado)',
          motivoRecomendacion:
              'Actividad en interiores protegida del viento en las dunas.',
          condicionesQueJustifican: 'Viento en Huacachina supera los 35 km/h.',
          mejorHorarioSugerido: '11:00 - 16:00',
          horarioAtencion: HorarioAtencion.paraVinedos(),
          latitud: -14.0750,
          longitud: -75.7250,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PantallaDetalleAlternativa(alternativa: alternativa),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alternativa Recomendada'), findsOneWidget);
        expect(
          find.text('Ruta del Pisco y Viñedos Tradicionales'),
          findsOneWidget,
        );
        expect(find.text('¿Por qué se recomienda?'), findsOneWidget);
        expect(find.text('Ver en el Mapa de Ika Travel'), findsOneWidget);
      },
    );
  });

  group('Mejoras: Navegación Inferior Global y NavegacionService', () {
    test('NavegacionService permite cambiar tabs globalmente', () {
      NavegacionService.irAInicio();
      expect(NavegacionService.indiceTabNotifier.value, equals(0));

      NavegacionService.irAActividades();
      expect(NavegacionService.indiceTabNotifier.value, equals(1));

      NavegacionService.irAMapa();
      expect(NavegacionService.indiceTabNotifier.value, equals(2));

      NavegacionService.irAPronostico();
      expect(NavegacionService.indiceTabNotifier.value, equals(3));

      NavegacionService.irAFavoritos();
      expect(NavegacionService.indiceTabNotifier.value, equals(4));

      NavegacionService.irAInicio();
      expect(NavegacionService.indiceTabNotifier.value, equals(0));
    });
  });

  group('Mejoras: Sección SOS y Contacto de Emergencia', () {
    final sosService = SosService();

    test('Permite registrar, actualizar y eliminar contacto de confianza', () {
      sosService.guardarContacto(
        nombre: 'María Gómez',
        telefono: '+51 987654321',
        relacion: 'Hermana',
      );

      expect(sosService.contactoNotifier.value, isNotNull);
      expect(sosService.contactoNotifier.value!.nombre, equals('María Gómez'));
      expect(
        sosService.contactoNotifier.value!.telefono,
        equals('+51 987654321'),
      );
      expect(sosService.contactoNotifier.value!.relacion, equals('Hermana'));

      sosService.eliminarContacto();
      expect(sosService.contactoNotifier.value, isNull);
    });

    test('Genera mensaje de emergencia con ubicación GPS cuando el permiso está concedido', () {
      sosService.setPermisoUbicacion(true);
      final mensajeConGps = sosService.generarMensajeEmergencia(
        modoPrueba: false,
      );

      expect(mensajeConGps.contains('¡NECESITO AYUDA!'), isTrue);
      expect(mensajeConGps.contains('https://maps.google.com'), isTrue);
      expect(mensajeConGps.contains('Huacachina'), isTrue);
    });

    test('Genera mensaje sin coordenadas cuando el permiso de ubicación es revocado', () {
      sosService.setPermisoUbicacion(false);
      final mensajeSinGps = sosService.generarMensajeEmergencia(
        modoPrueba: false,
      );

      expect(mensajeSinGps.contains('¡NECESITO AYUDA!'), isTrue);
      expect(mensajeSinGps.contains('Ubicación GPS no disponible'), isTrue);
      expect(mensajeSinGps.contains('https://maps.google.com'), isFalse);
    });

    test('Modo prueba agrega etiqueta explícita de simulación', () {
      final mensajePrueba = sosService.generarMensajeEmergencia(
        modoPrueba: true,
      );
      expect(
        mensajePrueba.contains(
          '[MODO PRUEBA IKA TRAVEL - NO ES UNA EMERGENCIA REAL]',
        ),
        isTrue,
      );
    });

    testWidgets(
      'PantallaSos renderiza botón SOS, números oficiales y aviso de plataforma',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(const MaterialApp(home: PantallaSos()));
        await tester.pumpAndSettle();

        expect(find.text('Asistencia y SOS'), findsOneWidget);
        expect(find.text('ACTIVAR SOS DE EMERGENCIA'), findsOneWidget);
        expect(find.text('Modo Prueba (Simular sin enviar)'), findsOneWidget);
        expect(find.text('Contacto de Confianza'), findsOneWidget);
        expect(find.text('Ubicación en el Mensaje'), findsOneWidget);
        expect(find.text('Vista Previa del Texto SOS'), findsOneWidget);
        expect(find.text('Centrales de Emergencia Oficiales'), findsOneWidget);
        expect(find.text('105'), findsOneWidget);
        expect(find.text('116'), findsOneWidget);
        expect(find.text('106'), findsOneWidget);
      },
    );
  });
}
