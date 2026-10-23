import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Categorías normalizadas de incidentes viales reales
enum TipoIncidente {
  cierreVia,
  accidente,
  obras,
  congestionSevera,
  peligro,
  otro,
}

/// Grado de impacto vial de un incidente
enum SeveridadIncidente {
  baja,
  moderada,
  alta,
  bloqueoTotal,
}

/// Estado de conexión y disponibilidad del proveedor de tráfico en vivo
enum EstadoProveedorTrafico {
  /// Sin clave API configurada. La app no finge datos y opera en modo estándar
  sinConfigurar,

  /// Consultando el servicio remoto oficial
  cargando,

  /// Conectado y sincronizado con datos reales
  conectado,

  /// Conexión exitosa y 0 incidentes reportados en la zona consultada
  sinIncidentes,

  /// Falla de conexión a internet o tiempo de espera agotado
  errorConexion,

  /// Límite de solicitudes de la cuota alcanzado
  cuotaExcedida,
}

/// Modelo de datos representativo de un incidente vial real en Ica
class IncidenteTrafico {
  final String id;
  final TipoIncidente tipo;
  final SeveridadIncidente severidad;
  final String descripcion;
  final String viaAfectada;
  final LatLng coordenadas;
  final List<LatLng> geometriaPolilinea;
  final double radioAfectacionMetros;
  final int demoraSegundos;
  final bool esBloqueoCompleto;
  final bool esConfirmado;
  final String proveedorFuente;
  final DateTime fechaActualizacion;
  final DateTime? fechaInicio;
  final DateTime? fechaFinEstimada;

  const IncidenteTrafico({
    required this.id,
    required this.tipo,
    required this.severidad,
    required this.descripcion,
    required this.viaAfectada,
    required this.coordenadas,
    this.geometriaPolilinea = const [],
    this.radioAfectacionMetros = 60.0,
    this.demoraSegundos = 0,
    this.esBloqueoCompleto = false,
    this.esConfirmado = true,
    required this.proveedorFuente,
    required this.fechaActualizacion,
    this.fechaInicio,
    this.fechaFinEstimada,
  });

  /// Ícono representativo según el tipo de incidente
  IconData get icono {
    switch (tipo) {
      case TipoIncidente.cierreVia:
        return Icons.do_not_disturb_on_rounded;
      case TipoIncidente.accidente:
        return Icons.car_crash_rounded;
      case TipoIncidente.obras:
        return Icons.construction_rounded;
      case TipoIncidente.congestionSevera:
        return Icons.traffic_rounded;
      case TipoIncidente.peligro:
        return Icons.warning_amber_rounded;
      case TipoIncidente.otro:
        return Icons.info_outline_rounded;
    }
  }

  /// Color semántico según la severidad
  Color get colorSeveridad {
    switch (severidad) {
      case SeveridadIncidente.bloqueoTotal:
        return const Color(0xFFD32F2F); // Rojo intenso
      case SeveridadIncidente.alta:
        return const Color(0xFFE65100); // Naranja oscuro
      case SeveridadIncidente.moderada:
        return const Color(0xFFF57C00); // Ámbar anaranjado
      case SeveridadIncidente.baja:
        return const Color(0xFFFBC02D); // Amarillo
    }
  }

  /// Etiqueta amigable en español
  String get nombreTipoEspanol {
    switch (tipo) {
      case TipoIncidente.cierreVia:
        return 'Cierre de vía';
      case TipoIncidente.accidente:
        return 'Accidente de tránsito';
      case TipoIncidente.obras:
        return 'Obras en la calzada';
      case TipoIncidente.congestionSevera:
        return 'Congestión severa';
      case TipoIncidente.peligro:
        return 'Peligro en la ruta';
      case TipoIncidente.otro:
        return 'Incidente vial';
    }
  }

  /// Nivel de impacto en español
  String get nombreSeveridadEspanol {
    switch (severidad) {
      case SeveridadIncidente.bloqueoTotal:
        return 'Bloqueo total';
      case SeveridadIncidente.alta:
        return 'Impacto alto';
      case SeveridadIncidente.moderada:
        return 'Demora moderada';
      case SeveridadIncidente.baja:
        return 'Impacto leve';
    }
  }

  /// Distancia en metros entre las coordenadas del incidente y un punto GPS
  double distanciaAPuntoMetros(LatLng punto) {
    return _distanciaHaversineMetros(coordenadas, punto);
  }

  /// Determina la distancia mínima en metros desde el incidente hacia cualquier punto de la ruta.
  /// Comprueba tanto el punto central como todos los vértices de la polilínea afectada (en cierres de vía extensos).
  double distanciaMinimaARutaMetros(List<LatLng> puntosRuta) {
    if (puntosRuta.isEmpty) return double.infinity;
    double minima = double.infinity;

    final puntosAComparar = [
      coordenadas,
      ...geometriaPolilinea,
    ];

    for (final pIncidente in puntosAComparar) {
      for (final puntoRuta in puntosRuta) {
        final d = _distanciaHaversineMetros(pIncidente, puntoRuta);
        if (d < minima) minima = d;
      }
    }
    return minima;
  }

  /// Verifica si el incidente interseca o está dentro del radio de afectación de la ruta
  bool afectaRuta(List<LatLng> puntosRuta, {double? umbralPersonalizadoMetros}) {
    if (puntosRuta.isEmpty) return false;
    final umbral = umbralPersonalizadoMetros ?? radioAfectacionMetros;
    return distanciaMinimaARutaMetros(puntosRuta) <= umbral;
  }

  /// Parsea la respuesta estándar de TomTom Incident Details v5 tolerando datos parciales
  factory IncidenteTrafico.fromTomTomJson(
    Map<String, dynamic> json, {
    String proveedor = 'TomTom Traffic API',
  }) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};

    final id = properties['id']?.toString() ??
        'inc_${DateTime.now().millisecondsSinceEpoch}';

    // Tipo de ícono según TomTom (0=desconocido, 1=accidente, 6=atasco, 7=obras, 8=cierre, 9=peligro, etc.)
    final iconCategory = properties['iconCategory'] as int? ?? 0;
    final tipo = _mapearTipoDesdeTomTom(iconCategory);

    // Severidad según TomTom (0=desconocida, 1=menor, 2=moderada, 3=mayor, 4=indefinida)
    final mag = properties['magnitudeOfDelay'] as int? ?? 0;
    final roadClosed =
        (properties['roadClosed'] as bool? ?? false) || iconCategory == 8;

    final severidad = roadClosed
        ? SeveridadIncidente.bloqueoTotal
        : switch (mag) {
            3 => SeveridadIncidente.alta,
            2 => SeveridadIncidente.moderada,
            1 => SeveridadIncidente.baja,
            _ => SeveridadIncidente.moderada,
          };

    // Descripción y vía
    final events = properties['events'] as List<dynamic>? ?? [];
    String desc = 'Incidente vial reportado';
    if (events.isNotEmpty && events.first is Map) {
      desc = events.first['description']?.toString() ?? desc;
    }
    final fromRoad = properties['from']?.toString() ?? '';
    final toRoad = properties['to']?.toString() ?? '';
    final via = fromRoad.isNotEmpty
        ? (toRoad.isNotEmpty ? '$fromRoad a $toRoad' : fromRoad)
        : 'Vía pública de Ica';

    // Coordenadas con tolerancia a formatos numéricos y strings
    LatLng coordPrincipal = const LatLng(-14.0678, -75.7286); // Fallback Ica
    final List<LatLng> polilinea = [];

    final geomType = geometry['type']?.toString();
    final coordinates = geometry['coordinates'];

    double? toDoubleVal(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    if (geomType == 'Point' && coordinates is List && coordinates.length >= 2) {
      final lon = toDoubleVal(coordinates[0]);
      final lat = toDoubleVal(coordinates[1]);
      if (lat != null && lon != null) {
        coordPrincipal = LatLng(lat, lon);
      }
    } else if (geomType == 'LineString' && coordinates is List && coordinates.isNotEmpty) {
      for (final p in coordinates) {
        if (p is List && p.length >= 2) {
          final lon = toDoubleVal(p[0]);
          final lat = toDoubleVal(p[1]);
          if (lat != null && lon != null) {
            polilinea.add(LatLng(lat, lon));
          }
        }
      }
      if (polilinea.isNotEmpty) {
        coordPrincipal = polilinea.first;
      }
    }

    final delaySeconds = (properties['delay'] as num?)?.round() ?? 0;
    final startTimeStr = properties['startTime']?.toString();
    final endTimeStr = properties['endTime']?.toString();

    return IncidenteTrafico(
      id: id,
      tipo: tipo,
      severidad: severidad,
      descripcion: desc,
      viaAfectada: via,
      coordenadas: coordPrincipal,
      geometriaPolilinea: polilinea,
      radioAfectacionMetros: roadClosed ? 90.0 : 65.0,
      demoraSegundos: delaySeconds,
      esBloqueoCompleto: roadClosed,
      esConfirmado: true,
      proveedorFuente: proveedor,
      fechaActualizacion: DateTime.now(),
      fechaInicio: startTimeStr != null ? DateTime.tryParse(startTimeStr) : null,
      fechaFinEstimada: endTimeStr != null ? DateTime.tryParse(endTimeStr) : null,
    );
  }

  static TipoIncidente _mapearTipoDesdeTomTom(int iconCategory) {
    switch (iconCategory) {
      case 8: // Road Closed
        return TipoIncidente.cierreVia;
      case 1: // Accident
      case 2: // Fog / accident-prone
        return TipoIncidente.accidente;
      case 7: // Road Works
        return TipoIncidente.obras;
      case 6: // Jam
        return TipoIncidente.congestionSevera;
      case 3: // Danger
      case 4: // Rain / weather hazard
      case 9: // Road condition
      case 10: // Lane restriction
        return TipoIncidente.peligro;
      default:
        return TipoIncidente.otro;
    }
  }

  static double _distanciaHaversineMetros(LatLng p1, LatLng p2) {
    const double rTierra = 6371000.0;
    final double lat1Rad = p1.latitude * (math.pi / 180.0);
    final double lat2Rad = p2.latitude * (math.pi / 180.0);
    final double deltaLat = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final double deltaLon = (p2.longitude - p1.longitude) * (math.pi / 180.0);

    final double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return rTierra * c;
  }
}
