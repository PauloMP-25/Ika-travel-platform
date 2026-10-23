import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ika_travel_mobile/models/itinerario_modelo.dart';
import 'package:ika_travel_mobile/models/navegacion_modelo.dart';
import 'package:ika_travel_mobile/services/traductor_maniobras.dart';
import 'package:ika_travel_mobile/services/osrm_service.dart';
import 'package:ika_travel_mobile/services/navegacion_service.dart';
import 'package:ika_travel_mobile/screens/pantalla_navegacion_guiada.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Navegación Vehicular - Traductor de Maniobras', () {
    test('Traduce giros a la derecha e izquierda con nombres de vías', () {
      const maniobraDerecha = ManiobraPaso(
        tipo: TipoManiobra.turn,
        modificador: ModificadorManiobra.right,
        ubicacion: LatLng(-14.0685, -75.7288),
      );
      final txtDerecha = TraductorManiobras.traducir(
        maniobra: maniobraDerecha,
        nombreVia: 'Avenida San Martín',
      );
      expect(txtDerecha, 'Gire a la derecha en Avenida San Martín');
      expect(TraductorManiobras.obtenerIcono(maniobraDerecha),
          Icons.turn_right_rounded);

      const maniobraIzquierda = ManiobraPaso(
        tipo: TipoManiobra.turn,
        modificador: ModificadorManiobra.left,
        ubicacion: LatLng(-14.0685, -75.7288),
      );
      final txtIzquierda = TraductorManiobras.traducir(
        maniobra: maniobraIzquierda,
        nombreVia: 'Calle Lima',
      );
      expect(txtIzquierda, 'Gire a la izquierda en Calle Lima');
      expect(TraductorManiobras.obtenerIcono(maniobraIzquierda),
          Icons.turn_left_rounded);
    });

    test('Traduce rotondas, giros en U y llegada a destino', () {
      const maniobraRotonda = ManiobraPaso(
        tipo: TipoManiobra.roundabout,
        modificador: ModificadorManiobra.straight,
        ubicacion: LatLng(-14.07, -75.73),
      );
      expect(
        TraductorManiobras.traducir(
          maniobra: maniobraRotonda,
          nombreVia: 'Panamericana Sur',
        ),
        'En el óvalo/rotonda, tome la salida hacia Panamericana Sur',
      );

      const maniobraUturn = ManiobraPaso(
        tipo: TipoManiobra.turn,
        modificador: ModificadorManiobra.uturn,
        ubicacion: LatLng(-14.07, -75.73),
      );
      expect(
        TraductorManiobras.traducir(
          maniobra: maniobraUturn,
          nombreVia: 'Av. Cutervo',
        ),
        'Haga un giro en U en Av. Cutervo',
      );

      const maniobraLlegada = ManiobraPaso(
        tipo: TipoManiobra.arrive,
        modificador: ModificadorManiobra.straight,
        ubicacion: LatLng(-14.0878, -75.7544),
      );
      expect(
        TraductorManiobras.traducir(
          maniobra: maniobraLlegada,
          nombreVia: '',
          nombreDestino: 'Huacachina',
        ),
        'Ha llegado a su destino: Huacachina',
      );
    });
  });

  group('Navegación Vehicular - Modelos de Datos', () {
    test('PasoNavegacion formatea distancias en metros y kilómetros', () {
      const pasoCorto = PasoNavegacion(
        id: 'p1',
        nombreVia: 'Av. Municipalidad',
        distanciaMetros: 350.0,
        duracionSegundos: 40.0,
        instruccionEspanol: 'Gire a la derecha',
        maniobra: ManiobraPaso(
          tipo: TipoManiobra.turn,
          modificador: ModificadorManiobra.right,
          ubicacion: LatLng(-14.0, -75.0),
        ),
        geometria: [],
        iconoManiobra: Icons.turn_right,
      );
      expect(pasoCorto.distanciaFormateada, '350 m');

      const pasoLargo = PasoNavegacion(
        id: 'p2',
        nombreVia: 'Carretera Panamericana Sur',
        distanciaMetros: 5400.0,
        duracionSegundos: 300.0,
        instruccionEspanol: 'Continúe recto',
        maniobra: ManiobraPaso(
          tipo: TipoManiobra.continueStraight,
          modificador: ModificadorManiobra.straight,
          ubicacion: LatLng(-14.0, -75.0),
        ),
        geometria: [],
        iconoManiobra: Icons.straight,
      );
      expect(pasoLargo.distanciaFormateada, '5.4 km');
    });

    test('RutaNavegacion calcula totales formateados de distancia y duración', () {
      const ruta = RutaNavegacion(
        origen: LatLng(-14.0685, -75.7288),
        destino: LatLng(-14.0878, -75.7544),
        nombreDestino: 'Huacachina',
        polilineaCompleta: [
          LatLng(-14.0685, -75.7288),
          LatLng(-14.0878, -75.7544),
        ],
        pasos: [],
        distanciaTotalMetros: 4250.0,
        duracionTotalSegundos: 450.0,
      );

      expect(ruta.distanciaTotalFormateada, '4.3 km');
      expect(ruta.duracionTotalFormateada, '8 min');
      expect(ruta.esSimulada, false);
      expect(ruta.esSeleccionada, true);
    });

    test('RutaNavegacion copyWith preserva atributos y actualiza selección', () {
      const ruta = RutaNavegacion(
        id: 'r_1',
        etiqueta: 'Alternativa 1',
        origen: LatLng(-14.0685, -75.7288),
        destino: LatLng(-14.0878, -75.7544),
        nombreDestino: 'Huacachina',
        polilineaCompleta: [],
        pasos: [],
        distanciaTotalMetros: 4500.0,
        duracionTotalSegundos: 500.0,
        esSeleccionada: false,
      );

      final seleccionada = ruta.copyWith(esSeleccionada: true);
      expect(seleccionada.esSeleccionada, true);
      expect(seleccionada.id, 'r_1');
      expect(seleccionada.etiqueta, 'Alternativa 1');
    });
  });

  group('Navegación Vehicular - Servicio de Navegación y Audio', () {
    test('Alternar silencio de voz actualiza correctamente el estado', () {
      final nav = NavegacionService();
      nav.vozSilenciadaNotifier.value = false;

      nav.alternarSilencioVoz();
      expect(nav.vozSilenciadaNotifier.value, true);

      nav.alternarSilencioVoz();
      expect(nav.vozSilenciadaNotifier.value, false);
    });

    test('OsrmService genera ruta con pasos detallados o simulada en fallback', () async {
      final osrm = OsrmService();
      final ruta = await osrm.obtenerRutaParaNavegacion(
        origen: const LatLng(-14.0685, -75.7288),
        destino: const LatLng(-14.0878, -75.7544),
        nombreDestino: 'Laguna Huacachina',
      );

      expect(ruta.pasos.isNotEmpty, true);
      expect(ruta.nombreDestino, 'Laguna Huacachina');
      expect(ruta.polilineaCompleta.length, greaterThanOrEqualTo(2));
      expect(ruta.distanciaTotalMetros, greaterThan(0));
    });

    test('OsrmService obtenerRutasConAlternativas devuelve lista de opciones', () async {
      final osrm = OsrmService();
      final rutas = await osrm.obtenerRutasConAlternativas(
        origen: const LatLng(-14.0685, -75.7288),
        destino: const LatLng(-14.0878, -75.7544),
        nombreDestino: 'Huacachina',
        incluirAlternativas: true,
      );

      expect(rutas.isNotEmpty, true);
      expect(rutas.first.esSeleccionada, true);
      expect(rutas.first.etiqueta, 'Ruta principal');
    });

    test('Detección de desvíos con umbral configurable y anti-falsos positivos', () {
      final nav = NavegacionService();
      const ruta = RutaNavegacion(
        origen: LatLng(-14.0685, -75.7288),
        destino: LatLng(-14.0878, -75.7544),
        nombreDestino: 'Huacachina',
        polilineaCompleta: [
          LatLng(-14.0685, -75.7288),
          LatLng(-14.0750, -75.7400),
          LatLng(-14.0878, -75.7544),
        ],
        pasos: [],
        distanciaTotalMetros: 4000.0,
        duracionTotalSegundos: 350.0,
      );

      // 1. Punto exactamente sobre la polilínea
      final puntoEnRuta = const LatLng(-14.0750, -75.7400);
      expect(nav.estaFueraDeRutaTest(puntoEnRuta, ruta), false);

      // 2. Punto muy alejado (a varios kilómetros de la ruta)
      final puntoDesviado = const LatLng(-14.1500, -75.8500);
      expect(nav.estaFueraDeRutaTest(puntoDesviado, ruta), true);

      // 3. Umbral configurable
      nav.umbralDesvioMetros = 80.0;
      expect(nav.umbralDesvioMetros, 80.0);
    });

    test('Ciclo de vida y detención cancela recursos y resetea estados', () async {
      final nav = NavegacionService();
      const ruta = RutaNavegacion(
        origen: LatLng(-14.0685, -75.7288),
        destino: LatLng(-14.0878, -75.7544),
        nombreDestino: 'Huacachina',
        polilineaCompleta: [
          LatLng(-14.0685, -75.7288),
          LatLng(-14.0878, -75.7544),
        ],
        pasos: [],
        distanciaTotalMetros: 2500.0,
        duracionTotalSegundos: 200.0,
      );

      // Iniciar en modo simulación
      await nav.iniciarNavegacion(ruta: ruta, usarSimulacionPrueba: true);
      expect(nav.estadoGpsNotifier.value, EstadoGPS.modoSimulacionPrueba);
      expect(nav.esUbicacionRealNotifier.value, false);

      // Detener
      nav.detenerNavegacion();
      expect(nav.estadoGpsNotifier.value, EstadoGPS.desactivado);
      expect(nav.esUbicacionRealNotifier.value, false);
    });
  });

  group('Navegación Vehicular - Mejoras Avanzadas Etapa 3', () {
    test('Selección y conmutación de rutas alternativas', () async {
      final nav = NavegacionService();
      const ruta1 = RutaNavegacion(
        id: 'ruta_0',
        etiqueta: 'Ruta principal',
        origen: LatLng(-14.0685, -75.7288),
        destino: LatLng(-14.0878, -75.7544),
        nombreDestino: 'Huacachina',
        polilineaCompleta: [LatLng(-14.0685, -75.7288), LatLng(-14.0878, -75.7544)],
        pasos: [],
        distanciaTotalMetros: 4200.0,
        duracionTotalSegundos: 400.0,
        esSeleccionada: true,
      );
      const ruta2 = RutaNavegacion(
        id: 'ruta_1',
        etiqueta: 'Alternativa 1',
        origen: LatLng(-14.0685, -75.7288),
        destino: LatLng(-14.0878, -75.7544),
        nombreDestino: 'Huacachina',
        polilineaCompleta: [LatLng(-14.0685, -75.7288), LatLng(-14.0878, -75.7544)],
        pasos: [],
        distanciaTotalMetros: 4600.0,
        duracionTotalSegundos: 460.0,
        esSeleccionada: false,
      );

      await nav.iniciarNavegacion(
        ruta: ruta1,
        rutasAlternativas: [ruta1, ruta2],
      );

      expect(nav.rutaActivaNotifier.value?.id, 'ruta_0');
      expect(nav.rutasAlternativasNotifier.value.length, 2);

      // Seleccionar alternativa
      nav.seleccionarRutaAlternativa(ruta2);
      expect(nav.rutaActivaNotifier.value?.id, 'ruta_1');
      expect(nav.rutasAlternativasNotifier.value.firstWhere((r) => r.id == 'ruta_1').esSeleccionada, true);
      expect(nav.rutasAlternativasNotifier.value.firstWhere((r) => r.id == 'ruta_0').esSeleccionada, false);

      nav.detenerNavegacion();
    });

    test('Progreso de viaje: actualiza distancia restante, ETA y tiempo transcurrido', () async {
      final nav = NavegacionService();
      const ruta = RutaNavegacion(
        origen: LatLng(-14.0685, -75.7288),
        destino: LatLng(-14.0878, -75.7544),
        nombreDestino: 'Huacachina',
        polilineaCompleta: [LatLng(-14.0685, -75.7288), LatLng(-14.0878, -75.7544)],
        pasos: [],
        distanciaTotalMetros: 4000.0,
        duracionTotalSegundos: 300.0,
      );

      await nav.iniciarNavegacion(ruta: ruta);

      // Verificamos inicialización de progreso
      expect(nav.distanciaRestanteTotalMetrosNotifier.value, 4000.0);
      expect(nav.horaEstimadaLlegadaNotifier.value.isNotEmpty, true);
      expect(nav.tiempoTranscurridoSegundosNotifier.value, 0);

      // Procesar posición cercana al destino
      nav.procesarPosicionTest(
        posicion: const LatLng(-14.0850, -75.7520),
        velocidadKmh: 45.0,
      );

      // Distancia debe haberse reducido drásticamente
      expect(nav.distanciaRestanteTotalMetrosNotifier.value, lessThan(1000.0));
      expect(nav.tiempoRestanteTotalSegundosNotifier.value, lessThan(300.0));

      nav.detenerNavegacion();
    });

    test('Múltiples destinos: preserva el itinerario y avanza a la siguiente parada', () async {
      final nav = NavegacionService();
      const parada1 = PuntoItinerario(
        id: 'p_1',
        nombre: 'Plaza de Armas',
        descripcion: 'Centro de la ciudad',
        coordenadas: LatLng(-14.0685, -75.7288),
      );
      const parada2 = PuntoItinerario(
        id: 'p_2',
        nombre: 'Bodega Tacama',
        descripcion: 'Viñedo histórico',
        coordenadas: LatLng(-14.0200, -75.7300),
      );
      const parada3 = PuntoItinerario(
        id: 'p_3',
        nombre: 'Huacachina',
        descripcion: 'Oasis turístico',
        coordenadas: LatLng(-14.0878, -75.7544),
      );

      const rutaInicial = RutaNavegacion(
        origen: LatLng(-14.0700, -75.7200),
        destino: LatLng(-14.0685, -75.7288),
        nombreDestino: 'Plaza de Armas',
        polilineaCompleta: [LatLng(-14.0700, -75.7200), LatLng(-14.0685, -75.7288)],
        pasos: [],
        distanciaTotalMetros: 1200.0,
        duracionTotalSegundos: 150.0,
      );

      await nav.iniciarNavegacion(
        ruta: rutaInicial,
        paradasItinerario: [parada1, parada2, parada3],
      );

      expect(nav.paradasItinerarioNotifier.value.length, 3);
      expect(nav.indiceParadaActualNotifier.value, 0);
      expect(nav.paradaActual?.nombre, 'Plaza de Armas');
      expect(nav.hayMasDestinos, true);

      // Avanzar a la segunda parada
      final exito = await nav.avanzarASiguienteParada();
      expect(exito, true);
      expect(nav.indiceParadaActualNotifier.value, 1);
      expect(nav.paradaActual?.nombre, 'Bodega Tacama');
      expect(nav.hayMasDestinos, true);
      // El itinerario original se mantiene intacto sin perder paradas
      expect(nav.paradasItinerarioNotifier.value.length, 3);

      // Avanzar a la tercera parada (última)
      final exitoFinal = await nav.avanzarASiguienteParada();
      expect(exitoFinal, true);
      expect(nav.indiceParadaActualNotifier.value, 2);
      expect(nav.paradaActual?.nombre, 'Huacachina');
      expect(nav.hayMasDestinos, false);

      nav.detenerNavegacion();
    });

    test('Detección de llegada: requiere lecturas consecutivas anti-jitter antes de disparar aviso', () async {
      final nav = NavegacionService();
      const destinoCoord = LatLng(-14.0878, -75.7544);
      const ruta = RutaNavegacion(
        origen: LatLng(-14.0685, -75.7288),
        destino: destinoCoord,
        nombreDestino: 'Oasis Huacachina',
        polilineaCompleta: [LatLng(-14.0685, -75.7288), destinoCoord],
        pasos: [],
        distanciaTotalMetros: 4000.0,
        duracionTotalSegundos: 350.0,
      );

      await nav.iniciarNavegacion(ruta: ruta);
      nav.umbralLlegadaMetros = 30.0;
      expect(nav.paradaAlcanzadaNotifier.value, isNull);

      // Lectura 1: Justo en el destino (< 30m)
      nav.procesarPosicionTest(posicion: destinoCoord);
      expect(nav.conteoLlegadasConsecutivasTest, 1);
      // Aún no debe declarar llegada porque requiere confirmación (2 lecturas)
      expect(nav.paradaAlcanzadaNotifier.value, isNull);

      // Lectura 2: Confirmación en el destino (< 30m)
      nav.procesarPosicionTest(posicion: destinoCoord);
      expect(nav.conteoLlegadasConsecutivasTest, greaterThanOrEqualTo(2));
      // Ahora sí se declara llegada validada
      expect(nav.paradaAlcanzadaNotifier.value, isNotNull);
      expect(nav.paradaAlcanzadaNotifier.value?.nombre, 'Oasis Huacachina');

      nav.detenerNavegacion();
    });
  });

  group('Navegación Vehicular - Interfaz Gráfica (HUD)', () {
    testWidgets('PantallaNavegacionGuiada renderiza tarjeta HUD, métricas ETA y barra inferior',
        (WidgetTester tester) async {
      final rutaDemo = RutaNavegacion(
        origen: const LatLng(-14.0685, -75.7288),
        destino: const LatLng(-14.0878, -75.7544),
        nombreDestino: 'Oasis de Huacachina',
        polilineaCompleta: const [
          LatLng(-14.0685, -75.7288),
          LatLng(-14.0750, -75.7400),
          LatLng(-14.0878, -75.7544),
        ],
        pasos: const [
          PasoNavegacion(
            id: 'paso_0',
            nombreVia: 'Avenida San Martín',
            distanciaMetros: 600.0,
            duracionSegundos: 60.0,
            instruccionEspanol: 'Inicie el recorrido por Avenida San Martín',
            maniobra: ManiobraPaso(
              tipo: TipoManiobra.depart,
              modificador: ModificadorManiobra.straight,
              ubicacion: LatLng(-14.0685, -75.7288),
            ),
            geometria: [
              LatLng(-14.0685, -75.7288),
              LatLng(-14.0750, -75.7400),
            ],
            iconoManiobra: Icons.navigation_rounded,
          ),
          PasoNavegacion(
            id: 'paso_1',
            nombreVia: 'Avenida La Rinconada',
            distanciaMetros: 3400.0,
            duracionSegundos: 320.0,
            instruccionEspanol: 'Gire a la derecha en Avenida La Rinconada',
            maniobra: ManiobraPaso(
              tipo: TipoManiobra.turn,
              modificador: ModificadorManiobra.right,
              ubicacion: LatLng(-14.0750, -75.7400),
            ),
            geometria: [
              LatLng(-14.0750, -75.7400),
              LatLng(-14.0878, -75.7544),
            ],
            iconoManiobra: Icons.turn_right_rounded,
          ),
        ],
        distanciaTotalMetros: 4000.0,
        duracionTotalSegundos: 380.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaNavegacionGuiada(rutaInicial: rutaDemo),
        ),
      );

      await tester.pump();

      // Verificar que se renderiza el destino en la barra de viaje
      expect(find.text('Oasis de Huacachina'), findsOneWidget);

      // Verificar que se renderiza el botón de finalizar
      expect(find.text('Finalizar'), findsOneWidget);

      // Verificar que existe el botón de silenciar voz
      expect(find.byType(Tooltip), findsWidgets);
    });
  });
}

