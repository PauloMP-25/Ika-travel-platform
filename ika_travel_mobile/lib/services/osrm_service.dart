import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/itinerario_modelo.dart';

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

  double _rad(double deg) => deg * math.pi / 180.0;
}
