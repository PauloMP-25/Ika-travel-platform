import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:ika_travel_mobile/models/navegacion_modelo.dart';
import 'package:ika_travel_mobile/models/trafico_modelo.dart';
import 'package:ika_travel_mobile/services/trafico_service.dart';

void main() {
  group('IncidenteTrafico - Modelo, Parsing y Tolerancia a Fallos', () {
    test('Parsea cierre de vía (roadClosed: true) desde formato TomTom Incident Details v5', () {
      final sampleTomTom = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [-75.7290, -14.0680] // Lon, Lat
        },
        'properties': {
          'id': 'tomtom_closure_01',
          'iconCategory': 8, // Road Closed
          'magnitudeOfDelay': 0,
          'roadClosed': true,
          'from': 'Av. San Martín',
          'to': 'Calle Lima',
          'delay': 360,
          'events': [
            {'code': 101, 'description': 'Cierre total por mantenimiento de tuberías'}
          ],
          'startTime': '2026-10-19T10:00:00Z',
          'endTime': '2026-10-19T22:00:00Z',
        }
      };

      final incidente = IncidenteTrafico.fromTomTomJson(sampleTomTom);

      expect(incidente.id, 'tomtom_closure_01');
      expect(incidente.tipo, TipoIncidente.cierreVia);
      expect(incidente.severidad, SeveridadIncidente.bloqueoTotal);
      expect(incidente.esBloqueoCompleto, isTrue);
      expect(incidente.esConfirmado, isTrue);
      expect(incidente.viaAfectada, 'Av. San Martín a Calle Lima');
      expect(incidente.descripcion, 'Cierre total por mantenimiento de tuberías');
      expect(incidente.coordenadas.latitude, closeTo(-14.0680, 0.0001));
      expect(incidente.coordenadas.longitude, closeTo(-75.7290, 0.0001));
      expect(incidente.demoraSegundos, 360);
      expect(incidente.radioAfectacionMetros, greaterThan(70.0));
    });

    test('Parsea incidente real de TomTom con LineString, delay nulo e iconCategory 8', () {
      final sampleRealTomTom = {
        'type': 'Feature',
        'properties': {
          'id': 'TTI-real-01',
          'iconCategory': 8,
          'magnitudeOfDelay': 4,
          'startTime': '2026-10-20T01:15:30Z',
          'endTime': null,
          'from': 'Calle Victoria',
          'to': 'Calle Amazonas',
          'length': 85.9738,
          'delay': null,
          'events': [
            {'code': 401, 'description': 'Cerrado'}
          ]
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-75.7564, -14.0188],
            [-75.7572, -14.0187]
          ]
        }
      };

      final incidente = IncidenteTrafico.fromTomTomJson(sampleRealTomTom);
      expect(incidente.tipo, TipoIncidente.cierreVia);
      expect(incidente.esBloqueoCompleto, isTrue);
      expect(incidente.severidad, SeveridadIncidente.bloqueoTotal);
      expect(incidente.viaAfectada, 'Calle Victoria a Calle Amazonas');
      expect(incidente.demoraSegundos, 0);
      expect(incidente.geometriaPolilinea.length, 2);
    });

    test('Parsea accidente con retraso alto y valores numéricos como string', () {
      final sampleAccident = {
        'geometry': {
          'type': 'Point',
          'coordinates': ['-75.7500', '-14.0800'] // Strings en vez de doubles
        },
        'properties': {
          'id': 'acc_02',
          'iconCategory': 1, // Accident
          'magnitudeOfDelay': 3, // Major
          'roadClosed': false,
          'from': 'Panamericana Sur km 303',
          'delay': 900,
          'events': [
            {'description': 'Colisión vehicular en carril derecho'}
          ]
        }
      };

      final incidente = IncidenteTrafico.fromTomTomJson(sampleAccident);

      expect(incidente.tipo, TipoIncidente.accidente);
      expect(incidente.severidad, SeveridadIncidente.alta);
      expect(incidente.esBloqueoCompleto, isFalse);
      expect(incidente.demoraSegundos, 900);
      expect(incidente.nombreTipoEspanol, 'Accidente de tránsito');
      expect(incidente.coordenadas.latitude, closeTo(-14.0800, 0.0001));
    });

    test('Tolerancia a datos incompletos o ausentes en JSON', () {
      final jsonVacio = <String, dynamic>{};

      final incidente = IncidenteTrafico.fromTomTomJson(jsonVacio);

      expect(incidente.id, isNotEmpty);
      expect(incidente.tipo, TipoIncidente.otro);
      expect(incidente.esBloqueoCompleto, isFalse);
      expect(incidente.descripcion, 'Incidente vial reportado');
      expect(incidente.coordenadas, isNotNull);
    });

    test('Calcula intersección espacial con polilínea de ruta (afectaRuta)', () {
      final incidente = IncidenteTrafico(
        id: 'inc_test',
        tipo: TipoIncidente.cierreVia,
        severidad: SeveridadIncidente.bloqueoTotal,
        descripcion: 'Cierre de prueba',
        viaAfectada: 'Calle San Martín',
        coordenadas: const LatLng(-14.0680, -75.7290),
        radioAfectacionMetros: 60.0,
        esBloqueoCompleto: true,
        proveedorFuente: 'Test',
        fechaActualizacion: DateTime.now(),
      );

      // Ruta que pasa a 10 metros del incidente
      final rutaCercana = [
        const LatLng(-14.0675, -75.7290),
        const LatLng(-14.0681, -75.7290), // Muy cerca (< 20m)
        const LatLng(-14.0690, -75.7290),
      ];

      // Ruta lejana (Huacachina, a ~4 km de distancia)
      final rutaLejana = [
        const LatLng(-14.0875, -75.7628),
        const LatLng(-14.0870, -75.7632),
      ];

      expect(incidente.afectaRuta(rutaCercana), isTrue);
      expect(incidente.afectaRuta(rutaLejana), isFalse);
      expect(incidente.afectaRuta([]), isFalse, reason: 'Ruta vacía no debe afectarse');
    });

    test('Detecta intersección cuando el incidente es un segmento extenso (LineString)', () {
      final incidenteSegmento = IncidenteTrafico(
        id: 'inc_tramo',
        tipo: TipoIncidente.cierreVia,
        severidad: SeveridadIncidente.bloqueoTotal,
        descripcion: 'Tramo cerrado de 400m',
        viaAfectada: 'Av. Cutervo',
        coordenadas: const LatLng(-14.0650, -75.7300),
        geometriaPolilinea: const [
          LatLng(-14.0650, -75.7300), // Inicio
          LatLng(-14.0670, -75.7300), // Medio
          LatLng(-14.0690, -75.7300), // Fin
        ],
        radioAfectacionMetros: 50.0,
        esBloqueoCompleto: true,
        proveedorFuente: 'Test',
        fechaActualizacion: DateTime.now(),
      );

      // Ruta que cruza solo por el medio del tramo cerrado
      final rutaCortaEnElMedio = [
        const LatLng(-14.0670, -75.7310),
        const LatLng(-14.0670, -75.7301), // Interseca el medio del LineString
        const LatLng(-14.0670, -75.7290),
      ];

      expect(incidenteSegmento.afectaRuta(rutaCortaEnElMedio), isTrue);
    });
  });

  group('TraficoService - Gestión de red, cuotas, errores y caché', () {
    test('Sin clave API: opera en modo estándar sin inventar incidentes simulados', () async {
      final service = TraficoService(
        apiKey: '', // Clave vacía intencional
      );

      final incidentes = await service.obtenerIncidentes();

      expect(incidentes, isEmpty);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.sinConfigurar);
      expect(service.tieneCredenciales, isFalse);
      expect(service.datosSonRecientes, isFalse);
      expect(service.apiKeyEnmascarada, '(no configurada)');
    });

    test('Enmascara claves configuradas correctamente para proteger credenciales', () {
      final service = TraficoService(apiKey: 'abcdef1234567890');
      expect(service.apiKeyEnmascarada, 'abcd...7890');

      final serviceCorta = TraficoService(apiKey: '1234');
      expect(serviceCorta.apiKeyEnmascarada, '********');
    });

    test('Conexión exitosa HTTP 200: almacena en caché y actualiza estado [Simulación de prueba]', () async {
      int peticionesHttp = 0;

      final mockClient = MockClient((request) async {
        peticionesHttp++;
        final mockResponse = {
          'incidents': [
            {
              'geometry': {
                'type': 'Point',
                'coordinates': [-75.7280, -14.0670]
              },
              'properties': {
                'id': 'mock_inc_1',
                'iconCategory': 7, // Works
                'magnitudeOfDelay': 2,
                'roadClosed': false,
                'from': 'Av. Cutervo',
                'events': [
                  {'description': 'Obras de repavimentación [Simulación de prueba]'}
                ]
              }
            }
          ]
        };
        return http.Response(json.encode(mockResponse), 200);
      });

      final service = TraficoService(
        client: mockClient,
        apiKey: 'TEST_VALID_KEY_123',
      );

      // Primera consulta: debe disparar HTTP
      final res1 = await service.obtenerIncidentes();
      expect(peticionesHttp, 1);
      expect(res1.length, 1);
      expect(res1.first.tipo, TipoIncidente.obras);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.conectado);
      expect(service.datosSonRecientes, isTrue);

      // Segunda consulta inmediata: debe resolver desde caché (TTL 5 min) sin petición HTTP adicional
      final res2 = await service.obtenerIncidentes();
      expect(peticionesHttp, 1, reason: 'El caché debe evitar consumo innecesario de cuota');
      expect(res2.length, 1);

      // Tercera consulta con forzarRecarga: debe realizar nueva petición HTTP
      final res3 = await service.obtenerIncidentes(forzarRecarga: true);
      expect(peticionesHttp, 2, reason: 'forzarRecarga debe saltarse el caché');
      expect(res3.length, 1);
    });

    test('HTTP 200 con lista vacía: establece estado sinIncidentes', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({'incidents': []}), 200);
      });

      final service = TraficoService(
        client: mockClient,
        apiKey: 'TEST_VALID_KEY_123',
      );

      final res = await service.obtenerIncidentes();
      expect(res, isEmpty);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.sinIncidentes);
      expect(service.datosSonRecientes, isTrue);
    });

    test('HTTP 400 Bad Request: maneja parámetros erróneos sin quebrar la app', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Bad request parameters', 400);
      });

      final service = TraficoService(client: mockClient, apiKey: 'TEST_KEY');
      final res = await service.obtenerIncidentes();

      expect(res, isEmpty);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.errorConexion);
      expect(service.mensajeEstadoNotifier.value, contains('400'));
    });

    test('HTTP 401/403 No autorizado: reporta problema de clave o cuota', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 403);
      });

      final service = TraficoService(client: mockClient, apiKey: 'INVALID_KEY');
      final res = await service.obtenerIncidentes();

      expect(res, isEmpty);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.cuotaExcedida);
      expect(service.mensajeEstadoNotifier.value, contains('403'));
    });

    test('HTTP 429 Cuota excedida: maneja error sin quebrar la aplicación', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Rate limit exceeded', 429);
      });

      final service = TraficoService(client: mockClient, apiKey: 'TEST_EXCEEDED_KEY');
      final res = await service.obtenerIncidentes();

      expect(res, isEmpty);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.cuotaExcedida);
      expect(service.mensajeEstadoNotifier.value, contains('429'));
    });

    test('HTTP 500 Error de servidor: degrada elegantemente a errorConexion', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = TraficoService(client: mockClient, apiKey: 'TEST_KEY');
      final res = await service.obtenerIncidentes();

      expect(res, isEmpty);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.errorConexion);
    });

    test('Tiempo de espera agotado (TimeoutException): maneja timeout limpiamente', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Timeout');
      });

      final service = TraficoService(client: mockClient, apiKey: 'TEST_KEY');
      final res = await service.obtenerIncidentes();

      expect(res, isEmpty);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.errorConexion);
      expect(service.mensajeEstadoNotifier.value, contains('agotado'));
    });

    test('Falla de red (SocketException / ClientException): degrada a modo errorConexion sin inventar datos', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network unreachable');
      });

      final service = TraficoService(
        client: mockClient,
        apiKey: 'TEST_VALID_KEY',
      );

      final res = await service.obtenerIncidentes();
      expect(res, isEmpty);
      expect(service.estadoProveedorNotifier.value, EstadoProveedorTrafico.errorConexion);
    });
  });

  group('TraficoService - Validación de rutas alternativas y seguridad vial', () {
    test('encontrarMejorAlternativaSinBloqueos selecciona la ruta que evade el corte vial si los datos son recientes', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({
          'incidents': [
            {
              'geometry': {
                'type': 'Point',
                'coordinates': [-75.7300, -14.0700]
              },
              'properties': {
                'id': 'bloqueo_centro',
                'iconCategory': 8, // Road Closed
                'roadClosed': true,
                'from': 'Av. Grau',
                'events': [{'description': 'Cierre por obras [Simulación de prueba]'}]
              }
            }
          ]
        }), 200);
      });

      final service = TraficoService(
        client: mockClient,
        apiKey: 'TEST_KEY',
      );

      await service.obtenerIncidentes();
      expect(service.datosSonRecientes, isTrue);

      // Ruta principal que atraviesa el punto de bloqueo
      final rutaPrincipal = RutaNavegacion(
        id: 'r_principal',
        etiqueta: 'Por Av. Grau',
        distanciaTotalMetros: 2500,
        duracionTotalSegundos: 350,
        origen: const LatLng(-14.0650, -75.7300),
        destino: const LatLng(-14.0750, -75.7300),
        nombreDestino: 'Plaza de Armas',
        polilineaCompleta: const [
          LatLng(-14.0650, -75.7300),
          LatLng(-14.0700, -75.7300), // Coincide con bloqueo
          LatLng(-14.0750, -75.7300),
        ],
        pasos: const [],
      );

      // Ruta alternativa que se desvía por el este y evita el bloqueo
      final rutaAlternativaSegura = RutaNavegacion(
        id: 'r_alterna',
        etiqueta: 'Por Circunvalación',
        distanciaTotalMetros: 3100,
        duracionTotalSegundos: 400,
        origen: const LatLng(-14.0650, -75.7300),
        destino: const LatLng(-14.0750, -75.7300),
        nombreDestino: 'Plaza de Armas',
        polilineaCompleta: const [
          LatLng(-14.0650, -75.7300),
          LatLng(-14.0650, -75.7150), // Desvío por el este
          LatLng(-14.0750, -75.7150),
          LatLng(-14.0750, -75.7300),
        ],
        pasos: const [],
      );

      // Comprobar que la principal está bloqueada
      expect(service.rutaTieneBloqueosTotales(rutaPrincipal.polilineaCompleta), isTrue);

      // Comprobar que la alternativa está libre
      expect(service.rutaTieneBloqueosTotales(rutaAlternativaSegura.polilineaCompleta), isFalse);

      // Validar selección segura
      final mejor = service.encontrarMejorAlternativaSinBloqueos(
        rutasCandidatas: [rutaPrincipal, rutaAlternativaSegura],
        rutaActual: rutaPrincipal,
      );

      expect(mejor, isNotNull);
      expect(mejor!.id, 'r_alterna');
      expect(mejor.etiqueta, 'Por Circunvalación');
    });

    test('NO afirma que una ruta esté libre de bloqueos si los datos NO son recientes o no hay clave', () {
      final serviceSinDatos = TraficoService(apiKey: '');

      final ruta1 = RutaNavegacion(
        id: 'r1',
        etiqueta: 'Ruta 1',
        distanciaTotalMetros: 2000,
        duracionTotalSegundos: 300,
        origen: const LatLng(-14.0650, -75.7300),
        destino: const LatLng(-14.0750, -75.7300),
        nombreDestino: 'Plaza de Armas',
        polilineaCompleta: const [LatLng(-14.0650, -75.7300)],
        pasos: const [],
      );

      final ruta2 = RutaNavegacion(
        id: 'r2',
        etiqueta: 'Ruta 2',
        distanciaTotalMetros: 2200,
        duracionTotalSegundos: 330,
        origen: const LatLng(-14.0650, -75.7300),
        destino: const LatLng(-14.0750, -75.7300),
        nombreDestino: 'Plaza de Armas',
        polilineaCompleta: const [LatLng(-14.0650, -75.7200)],
        pasos: const [],
      );

      expect(serviceSinDatos.datosSonRecientes, isFalse);

      // Debe retornar null porque sin datos recientes no se puede aseverar seguridad
      final resultado = serviceSinDatos.encontrarMejorAlternativaSinBloqueos(
        rutasCandidatas: [ruta1, ruta2],
        rutaActual: ruta1,
      );

      expect(resultado, isNull, reason: 'No se debe validar una alternativa como segura sin datos recientes');
    });

    test('No recomienda desvío automático si todas las alternativas también están bloqueadas', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({
          'incidents': [
            {
              'geometry': {
                'type': 'Point',
                'coordinates': [-75.7300, -14.0700]
              },
              'properties': {
                'id': 'bloqueo_unico_acceso',
                'iconCategory': 8,
                'roadClosed': true,
                'from': 'Puente Único',
                'events': [{'description': 'Puente cerrado [Simulación de prueba]'}]
              }
            }
          ]
        }), 200);
      });

      final service = TraficoService(client: mockClient, apiKey: 'TEST_KEY');
      await service.obtenerIncidentes();

      final ruta1 = RutaNavegacion(
        id: 'r1',
        etiqueta: 'Ruta 1',
        distanciaTotalMetros: 2000,
        duracionTotalSegundos: 300,
        origen: const LatLng(-14.0650, -75.7300),
        destino: const LatLng(-14.0750, -75.7300),
        nombreDestino: 'Plaza de Armas',
        polilineaCompleta: const [LatLng(-14.0700, -75.7300)],
        pasos: const [],
      );

      final ruta2 = RutaNavegacion(
        id: 'r2',
        etiqueta: 'Ruta 2',
        distanciaTotalMetros: 2200,
        duracionTotalSegundos: 330,
        origen: const LatLng(-14.0650, -75.7300),
        destino: const LatLng(-14.0750, -75.7300),
        nombreDestino: 'Plaza de Armas',
        polilineaCompleta: const [LatLng(-14.0700, -75.7300)], // También pasa por el mismo punto
        pasos: const [],
      );

      final alternativa = service.encontrarMejorAlternativaSinBloqueos(
        rutasCandidatas: [ruta1, ruta2],
        rutaActual: ruta1,
      );

      expect(alternativa, isNull, reason: 'No se debe recomendar desvío sin validar que esté libre de cierres');
    });
  });
}
