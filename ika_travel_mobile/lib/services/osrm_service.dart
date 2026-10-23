import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/itinerario_modelo.dart';
import '../models/navegacion_modelo.dart';
import 'traductor_maniobras.dart';

/// Cliente para la API pública de OSRM (Open Source Routing Machine).
///
/// CONDICIONES DE USO Y LIMITACIONES:
/// ─────────────────────────────────
/// • Servidor demo en uso: router.project-osrm.org
/// • Uso permitido: desarrollo y demostración (no producción a gran escala)
/// • Sin clave API ni registro requerido
/// • Sin SLA ni garantía de disponibilidad
/// • Rate limit implícito: ~1 req/seg por IP para ser cortés
/// • Cobertura: rutas en carretera a nivel mundial (perfil "driving")
/// • En caso de falla, el servicio retorna una ruta simulada (línea recta)
///   claramente etiquetada como [FuenteRuta.simulada]
///
/// Referencias:
///   https://router.project-osrm.org
///   https://project-osrm.org/docs/v5.24.0/api/#route-service
class OsrmService {
  static const String _base = 'https://router.project-osrm.org';
  static const Duration _timeout = Duration(seconds: 8);

  OsrmService._();
  static final OsrmService _instancia = OsrmService._();
  factory OsrmService() => _instancia;

  /// Calcula un tramo de ruta desde [origen] hasta [destino].
  ///
  /// Si OSRM responde correctamente devuelve [FuenteRuta.osrm].
  /// Si hay error de red o respuesta inválida devuelve [FuenteRuta.simulada]
  /// con distancia y tiempo calculados por línea recta (velocidad media 60 km/h).
  Future<TramoRuta> calcularTramo({
    required PuntoItinerario origen,
    required PuntoItinerario destino,
    required Color color,
  }) async {
    try {
      final tramo = await _consultarOsrm(
        origen: origen,
        destino: destino,
        color: color,
      );
      return tramo;
    } catch (e) {
      debugPrint('[OsrmService] Error calculando tramo: $e → usando ruta simulada');
      return _tramoSimulado(origen: origen, destino: destino, color: color);
    }
  }

  Future<TramoRuta> _consultarOsrm({
    required PuntoItinerario origen,
    required PuntoItinerario destino,
    required Color color,
  }) async {
    // OSRM espera: /route/v1/{profile}/{lon1},{lat1};{lon2},{lat2}
    final lon1 = origen.coordenadas.longitude.toStringAsFixed(6);
    final lat1 = origen.coordenadas.latitude.toStringAsFixed(6);
    final lon2 = destino.coordenadas.longitude.toStringAsFixed(6);
    final lat2 = destino.coordenadas.latitude.toStringAsFixed(6);

    final uri = Uri.parse(
      '$_base/route/v1/driving/$lon1,$lat1;$lon2,$lat2'
      '?overview=full&geometries=geojson',
    );

    final respuesta = await http.get(uri).timeout(_timeout);

    if (respuesta.statusCode != 200) {
      throw Exception('OSRM HTTP ${respuesta.statusCode}');
    }

    final body = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final codigo = body['code'] as String?;
    if (codigo != 'Ok') throw Exception('OSRM code: $codigo');

    final rutas = body['routes'] as List;
    if (rutas.isEmpty) throw Exception('OSRM: sin rutas');

    final ruta = rutas.first as Map<String, dynamic>;
    final distanciaM = (ruta['distance'] as num).toDouble();
    final duracionS = (ruta['duration'] as num).toDouble();

    final geometry = ruta['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List;

    // GeoJSON: [longitude, latitude]
    final polilinea = coords
        .map((c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();

    return TramoRuta(
      idOrigen: origen.id,
      idDestino: destino.id,
      polilinea: polilinea,
      distanciaKm: distanciaM / 1000.0,
      duracionMinutos: (duracionS / 60).round(),
      fuenteRuta: FuenteRuta.osrm,
      color: color,
    );
  }

  /// Ruta simulada: línea recta entre los dos puntos.
  /// Distancia haversine real, tiempo asumiendo 60 km/h.
  TramoRuta _tramoSimulado({
    required PuntoItinerario origen,
    required PuntoItinerario destino,
    required Color color,
  }) {
    final distKm = _distanciaHaversineKm(
      origen.coordenadas,
      destino.coordenadas,
    );
    // Multiplicamos por 1.3 para aproximar que la ruta real es más larga que la línea recta
    final distAjustada = distKm * 1.3;
    // Asume velocidad media de 60 km/h en carretera
    final durMin = (distAjustada / 60.0 * 60).round();

    return TramoRuta(
      idOrigen: origen.id,
      idDestino: destino.id,
      polilinea: [origen.coordenadas, destino.coordenadas],
      distanciaKm: distAjustada,
      duracionMinutos: durMin,
      fuenteRuta: FuenteRuta.simulada,
      color: color,
    );
  }

  /// Fórmula haversine para distancia en km entre dos coordenadas
  double _distanciaHaversineKm(LatLng a, LatLng b) {
    const r = 6371.0; // radio de la Tierra en km
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// Obtiene una lista de rutas (la principal y alternativas cuando OSRM las proporcione).
  ///
  /// No inventa rutas falsas si el servicio sólo retorna una opción.
  Future<List<RutaNavegacion>> obtenerRutasConAlternativas({
    required LatLng origen,
    required LatLng destino,
    String? nombreDestino,
    bool incluirAlternativas = true,
  }) async {
    final lon1 = origen.longitude.toStringAsFixed(6);
    final lat1 = origen.latitude.toStringAsFixed(6);
    final lon2 = destino.longitude.toStringAsFixed(6);
    final lat2 = destino.latitude.toStringAsFixed(6);

    final paramAlternativas = incluirAlternativas ? '&alternatives=true' : '';
    final uri = Uri.parse(
      '$_base/route/v1/driving/$lon1,$lat1;$lon2,$lat2'
      '?overview=full&geometries=geojson&steps=true$paramAlternativas',
    );

    try {
      final respuesta = await http.get(uri).timeout(_timeout);
      if (respuesta.statusCode != 200) {
        throw Exception('OSRM HTTP ${respuesta.statusCode}');
      }

      final body = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final codigo = body['code'] as String?;
      if (codigo != 'Ok') throw Exception('OSRM code: $codigo');

      final rutas = body['routes'] as List;
      if (rutas.isEmpty) throw Exception('OSRM: sin rutas');

      final listaRutas = <RutaNavegacion>[];

      for (int i = 0; i < rutas.length; i++) {
        final r = rutas[i] as Map<String, dynamic>;
        final distanciaTotalM = (r['distance'] as num).toDouble();
        final duracionTotalS = (r['duration'] as num).toDouble();

        final geometry = r['geometry'] as Map<String, dynamic>;
        final coords = geometry['coordinates'] as List;
        final polilineaCompleta = coords
            .map((c) => LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ))
            .toList();

        final pasos = <PasoNavegacion>[];
        final legs = (r['legs'] as List?) ?? [];
        String? viaPrincipal;
        double maxDistVia = 0.0;

        if (legs.isNotEmpty) {
          final rawSteps = (legs.first['steps'] as List?) ?? [];
          for (int j = 0; j < rawSteps.length; j++) {
            final s = rawSteps[j] as Map<String, dynamic>;
            final distM = (s['distance'] as num).toDouble();
            final durS = (s['duration'] as num).toDouble();
            final name = (s['name'] as String?) ?? '';
            final maneuverJson = (s['maneuver'] as Map<String, dynamic>?) ?? {};
            final maniobra = ManiobraPaso.fromJson(maneuverJson);

            if (name.isNotEmpty && distM > maxDistVia) {
              maxDistVia = distM;
              viaPrincipal = name;
            }

            final stepGeom = s['geometry'] as Map<String, dynamic>?;
            final stepCoords = (stepGeom?['coordinates'] as List?) ?? [];
            final stepPolilinea = stepCoords
                .map((c) => LatLng(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    ))
                .toList();

            final instruccion = TraductorManiobras.traducir(
              maniobra: maniobra,
              nombreVia: name,
              nombreDestino: nombreDestino,
            );

            final icono = TraductorManiobras.obtenerIcono(maniobra);

            pasos.add(PasoNavegacion(
              id: 'paso_${i}_$j',
              nombreVia: name,
              distanciaMetros: distM,
              duracionSegundos: durS,
              instruccionEspanol: instruccion,
              maniobra: maniobra,
              geometria: stepPolilinea,
              iconoManiobra: icono,
            ));
          }
        }

        final resumenVia = viaPrincipal != null && viaPrincipal.isNotEmpty
            ? 'Por $viaPrincipal'
            : null;

        listaRutas.add(RutaNavegacion(
          id: 'ruta_$i',
          etiqueta: i == 0 ? 'Ruta principal' : 'Alternativa $i',
          origen: origen,
          destino: destino,
          nombreDestino: nombreDestino ?? 'Destino',
          polilineaCompleta: polilineaCompleta,
          pasos: pasos,
          distanciaTotalMetros: distanciaTotalM,
          duracionTotalSegundos: duracionTotalS,
          esSimulada: false,
          esSeleccionada: (i == 0),
          resumenVia: resumenVia,
        ));
      }

      return listaRutas;
    } catch (e) {
      debugPrint('[OsrmService] Error en navegación OSRM: $e → usando ruta simulada');
      return [
        _rutaNavegacionSimulada(
          origen: origen,
          destino: destino,
          nombreDestino: nombreDestino,
        )
      ];
    }
  }

  /// Obtiene la ruta principal con pasos detallados para la navegación.
  Future<RutaNavegacion> obtenerRutaParaNavegacion({
    required LatLng origen,
    required LatLng destino,
    String? nombreDestino,
  }) async {
    final rutas = await obtenerRutasConAlternativas(
      origen: origen,
      destino: destino,
      nombreDestino: nombreDestino,
      incluirAlternativas: true,
    );
    return rutas.first;
  }

  /// Obtiene una ruta que pasa obligatoriamente por un punto de desvío [puntoDesvio]
  /// para sortear una calle cerrada o incidente vial confirmado.
  Future<RutaNavegacion?> obtenerRutaConDesvio({
    required LatLng origen,
    required LatLng destino,
    required LatLng puntoDesvio,
    String? nombreDestino,
    String etiqueta = 'Vía alterna',
  }) async {
    final lon1 = origen.longitude.toStringAsFixed(6);
    final lat1 = origen.latitude.toStringAsFixed(6);
    final lonW = puntoDesvio.longitude.toStringAsFixed(6);
    final latW = puntoDesvio.latitude.toStringAsFixed(6);
    final lon2 = destino.longitude.toStringAsFixed(6);
    final lat2 = destino.latitude.toStringAsFixed(6);

    final uri = Uri.parse(
      '$_base/route/v1/driving/$lon1,$lat1;$lonW,$latW;$lon2,$lat2'
      '?overview=full&geometries=geojson&steps=true',
    );

    try {
      final respuesta = await http.get(uri).timeout(_timeout);
      if (respuesta.statusCode != 200) return null;
      final body = jsonDecode(respuesta.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;
      final rutas = body['routes'] as List;
      if (rutas.isEmpty) return null;

      final r = rutas.first as Map<String, dynamic>;
      final distanciaTotalM = (r['distance'] as num).toDouble();
      final duracionTotalS = (r['duration'] as num).toDouble();

      final geometry = r['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List;
      final polilineaCompleta = coords
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      final pasos = <PasoNavegacion>[];
      final legs = (r['legs'] as List?) ?? [];
      String? viaPrincipal;
      double maxDistVia = 0.0;

      for (final leg in legs) {
        final rawSteps = (leg['steps'] as List?) ?? [];
        for (final s in rawSteps) {
          final distM = (s['distance'] as num).toDouble();
          final durS = (s['duration'] as num).toDouble();
          final name = (s['name'] as String?) ?? '';
          final maneuverJson = (s['maneuver'] as Map<String, dynamic>?) ?? {};
          final maniobra = ManiobraPaso.fromJson(maneuverJson);

          if (name.isNotEmpty && distM > maxDistVia) {
            maxDistVia = distM;
            viaPrincipal = name;
          }

          final stepGeom = s['geometry'] as Map<String, dynamic>?;
          final stepCoords = (stepGeom?['coordinates'] as List?) ?? [];
          final stepPolilinea = stepCoords
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();

          final instruccion = TraductorManiobras.traducir(
            maniobra: maniobra,
            nombreVia: name,
            nombreDestino: nombreDestino,
          );
          final icono = TraductorManiobras.obtenerIcono(maniobra);

          pasos.add(PasoNavegacion(
            id: 'desvio_step_${pasos.length}',
            nombreVia: name,
            distanciaMetros: distM,
            duracionSegundos: durS,
            instruccionEspanol: instruccion,
            maniobra: maniobra,
            geometria: stepPolilinea,
            iconoManiobra: icono,
          ));
        }
      }

      final resumenVia = viaPrincipal != null && viaPrincipal.isNotEmpty
          ? 'Por $viaPrincipal'
          : 'Por calles alternas';

      return RutaNavegacion(
        id: 'ruta_desvio_${DateTime.now().millisecondsSinceEpoch}',
        etiqueta: etiqueta,
        origen: origen,
        destino: destino,
        nombreDestino: nombreDestino ?? 'Destino',
        polilineaCompleta: polilineaCompleta,
        pasos: pasos,
        distanciaTotalMetros: distanciaTotalM,
        duracionTotalSegundos: duracionTotalS,
        esSimulada: false,
        resumenVia: resumenVia,
      );
    } catch (e) {
      debugPrint('[OsrmService] Error calculando desvío: $e');
      return null;
    }
  }

  RutaNavegacion _rutaNavegacionSimulada({
    required LatLng origen,
    required LatLng destino,
    String? nombreDestino,
  }) {
    final distKm = _distanciaHaversineKm(origen, destino) * 1.3;
    final distM = distKm * 1000.0;
    final durS = (distKm / 60.0) * 3600.0;

    final pasos = [
      PasoNavegacion(
        id: 'paso_sim_0',
        nombreVia: 'Trayecto referencial',
        distanciaMetros: distM,
        duracionSegundos: durS,
        instruccionEspanol: 'Avance en dirección a ${nombreDestino ?? "su destino"} (Servidor OSRM no disponible)',
        maniobra: ManiobraPaso(
          tipo: TipoManiobra.depart,
          modificador: ModificadorManiobra.straight,
          ubicacion: origen,
        ),
        geometria: [origen, destino],
        iconoManiobra: Icons.navigation_rounded,
      ),
      PasoNavegacion(
        id: 'paso_sim_1',
        nombreVia: nombreDestino ?? 'Destino',
        distanciaMetros: 0,
        duracionSegundos: 0,
        instruccionEspanol: 'Ha llegado a su destino: ${nombreDestino ?? "Destino"}',
        maniobra: ManiobraPaso(
          tipo: TipoManiobra.arrive,
          modificador: ModificadorManiobra.straight,
          ubicacion: destino,
        ),
        geometria: [destino],
        iconoManiobra: Icons.flag_rounded,
      ),
    ];

    return RutaNavegacion(
      origen: origen,
      destino: destino,
      nombreDestino: nombreDestino ?? 'Destino',
      polilineaCompleta: [origen, destino],
      pasos: pasos,
      distanciaTotalMetros: distM,
      duracionTotalSegundos: durS,
      esSimulada: true,
    );
  }

  double _rad(double deg) => deg * math.pi / 180.0;
}
