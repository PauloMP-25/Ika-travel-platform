import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Destinos turísticos predefinidos de la región de Ica
class DestinosPredefinidos {
  static const List<PuntoItinerario> lista = [
    PuntoItinerario(
      id: 'huacachina',
      nombre: 'Huacachina',
      descripcion: 'Oasis en las dunas — sandboarding y tubulares',
      coordenadas: LatLng(-14.08759, -75.76306),
      tiempoVisitaMinutos: 120, // 2 horas de actividades en dunas
    ),
    PuntoItinerario(
      id: 'luren',
      nombre: 'Santuario del Señor de Luren',
      descripcion: 'Templo histórico y patrón religioso de Ica',
      coordenadas: LatLng(-14.07066, -75.72553), // Ubicación exacta del atrio y templo
      tiempoVisitaMinutos: 45, // 45 min para visita y devoción
    ),
    PuntoItinerario(
      id: 'paracas_reserva',
      nombre: 'Reserva Nacional Paracas',
      descripcion: 'Biodiversidad marina y miradores de la Pacífico',
      coordenadas: LatLng(-13.88330, -76.26670),
      tiempoVisitaMinutos: 180, // 3 horas de recorrido
    ),
    PuntoItinerario(
      id: 'islas_ballestas',
      nombre: 'Islas Ballestas',
      descripcion: 'Fauna marina — lobos de mar y pingüinos Humboldt',
      coordenadas: LatLng(-13.83410, -76.24886),
      tiempoVisitaMinutos: 120, // 2 horas tour en lancha
    ),
    PuntoItinerario(
      id: 'vinedos_ica',
      nombre: 'Viñedos y Bodega Tacama',
      descripcion: 'Ruta del pisco — viñedos más antiguos de Sudamérica y catas',
      coordenadas: LatLng(-14.00175, -75.71683),
      tiempoVisitaMinutos: 90, // 1h 30 min de cata y recorrido
    ),
    PuntoItinerario(
      id: 'nazca_lineas',
      nombre: 'Líneas de Nazca',
      descripcion: 'Geoglifos patrimonio UNESCO — sobrevuelo en avioneta',
      coordenadas: LatLng(-14.72990, -75.11480),
      tiempoVisitaMinutos: 120, // 2 horas (espera y sobrevuelo)
    ),
    PuntoItinerario(
      id: 'plaza_ica',
      nombre: 'Plaza de Armas de Ica',
      descripcion: 'Centro histórico, catedral y gastronomía local',
      coordenadas: LatLng(-14.06402, -75.72907),
      tiempoVisitaMinutos: 40,
    ),
    PuntoItinerario(
      id: 'cachiche',
      nombre: 'Cachiche',
      descripcion: 'Pueblo de brujas — palmera de 7 cabezas y pisco artesanal',
      coordenadas: LatLng(-14.09454, -75.73643),
      tiempoVisitaMinutos: 60, // 1 hora
    ),
    PuntoItinerario(
      id: 'pisco_ciudad',
      nombre: 'Ciudad de Pisco',
      descripcion: 'Puerto y punto de partida a las Islas Ballestas',
      coordenadas: LatLng(-13.70970, -76.20220),
      tiempoVisitaMinutos: 60,
    ),
  ];

  /// Punto de origen predeterminado: Plaza de Armas de Ica
  static const PuntoItinerario origenPredeterminado = PuntoItinerario(
    id: 'ica_centro',
    nombre: 'Plaza de Armas de Ica',
    descripcion: 'Punto de partida cívico en el centro de Ica',
    coordenadas: LatLng(-14.06402, -75.72907),
    esUbicacionSimulada: false,
  );
}

/// Un punto dentro del itinerario (origen o destino)
class PuntoItinerario {
  final String id;
  final String nombre;
  final String descripcion;
  final LatLng coordenadas;

  /// true cuando se usó la ubicación por defecto en lugar de GPS real
  final bool esUbicacionSimulada;

  /// Tiempo sugerido de estadía/visita en este punto (en minutos)
  final int tiempoVisitaMinutos;

  const PuntoItinerario({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.coordenadas,
    this.esUbicacionSimulada = false,
    this.tiempoVisitaMinutos = 45,
  });

  String get tiempoVisitaFormateado {
    if (tiempoVisitaMinutos <= 0) return '';
    if (tiempoVisitaMinutos < 60) return '$tiempoVisitaMinutos min';
    final h = tiempoVisitaMinutos ~/ 60;
    final m = tiempoVisitaMinutos % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'lat': coordenadas.latitude,
        'lon': coordenadas.longitude,
        'esUbicacionSimulada': esUbicacionSimulada,
        'tiempoVisitaMinutos': tiempoVisitaMinutos,
      };

  factory PuntoItinerario.fromJson(Map<String, dynamic> json) =>
      PuntoItinerario(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String,
        coordenadas: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lon'] as num).toDouble(),
        ),
        esUbicacionSimulada: json['esUbicacionSimulada'] as bool? ?? false,
        tiempoVisitaMinutos: json['tiempoVisitaMinutos'] as int? ?? 45,
      );

  @override
  bool operator ==(Object other) =>
      other is PuntoItinerario && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Paleta de colores para tramos de ruta (máx. 7 tramos visibles)
const List<Color> coloresTramos = [
  Color(0xFF1565C0), // azul profundo
  Color(0xFF2E7D32), // verde bosque
  Color(0xFFE65100), // naranja quemado
  Color(0xFF6A1B9A), // violeta
  Color(0xFF00695C), // verde azulado
  Color(0xFFC62828), // rojo
  Color(0xFF4527A0), // indigo
];

/// Color hexadecimal string para un tramo según su índice
Color colorParaTramo(int indice) =>
    coloresTramos[indice % coloresTramos.length];

/// Fuente de los datos de un tramo de ruta
enum FuenteRuta {
  /// Datos calculados por OSRM — referencial, no garantizado
  osrm,

  /// Datos de ruta simulados (línea recta) — OSRM no disponible
  simulada,
}

/// Representación de un segmento de ruta entre dos puntos consecutivos
class TramoRuta {
  /// ID del punto de origen de este tramo
  final String idOrigen;

  /// ID del punto de destino de este tramo
  final String idDestino;

  /// Coordenadas de la polilínea (puede ser real o línea recta simulada)
  final List<LatLng> polilinea;

  /// Distancia en kilómetros
  final double distanciaKm;

  /// Duración estimada en minutos
  final int duracionMinutos;

  /// Fuente de los datos de ruta
  final FuenteRuta fuenteRuta;

  /// Color asignado para visualización en el mapa
  final Color color;

  const TramoRuta({
    required this.idOrigen,
    required this.idDestino,
    required this.polilinea,
    required this.distanciaKm,
    required this.duracionMinutos,
    required this.fuenteRuta,
    required this.color,
  });

  bool get esSimulado => fuenteRuta == FuenteRuta.simulada;

  String get etiquetaFuente => switch (fuenteRuta) {
        FuenteRuta.osrm => 'Ruta OSRM (referencial)',
        FuenteRuta.simulada => 'Ruta simulada (línea recta)',
      };

  String get distanciaFormateada {
    if (distanciaKm < 1) return '${(distanciaKm * 1000).round()} m';
    return '${distanciaKm.toStringAsFixed(1)} km';
  }

  String get duracionFormateada {
    if (duracionMinutos < 60) return '$duracionMinutos min';
    final h = duracionMinutos ~/ 60;
    final m = duracionMinutos % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  Map<String, dynamic> toJson() => {
        'idOrigen': idOrigen,
        'idDestino': idDestino,
        'polilinea': polilinea
            .map((p) => {'lat': p.latitude, 'lon': p.longitude})
            .toList(),
        'distanciaKm': distanciaKm,
        'duracionMinutos': duracionMinutos,
        'fuenteRuta': fuenteRuta.name,
        'colorValue': color.toARGB32(),
      };

  factory TramoRuta.fromJson(Map<String, dynamic> json) => TramoRuta(
        idOrigen: json['idOrigen'] as String,
        idDestino: json['idDestino'] as String,
        polilinea: (json['polilinea'] as List)
            .map((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lon'] as num).toDouble(),
                ))
            .toList(),
        distanciaKm: (json['distanciaKm'] as num).toDouble(),
        duracionMinutos: json['duracionMinutos'] as int,
        fuenteRuta: FuenteRuta.values.firstWhere(
          (f) => f.name == json['fuenteRuta'],
          orElse: () => FuenteRuta.simulada,
        ),
        color: Color(json['colorValue'] as int),
      );
}

/// Itinerario completo de viaje
class ItinerarioViaje {
  final String id;
  final String titulo;

  /// puntos[0] = origen, puntos[1..n] = destinos
  final List<PuntoItinerario> puntos;

  /// tramos[i] conecta puntos[i] → puntos[i+1]
  final List<TramoRuta> tramos;

  final DateTime fechaCreacion;

  const ItinerarioViaje({
    required this.id,
    required this.titulo,
    required this.puntos,
    this.tramos = const [],
    required this.fechaCreacion,
  });

  PuntoItinerario? get origen => puntos.isNotEmpty ? puntos.first : null;
  List<PuntoItinerario> get destinos =>
      puntos.length > 1 ? puntos.sublist(1) : [];
  bool get tieneOrigen => puntos.isNotEmpty;
  bool get tieneDestinos => puntos.length > 1;
  bool get tieneRutas => tramos.isNotEmpty;

  double get distanciaTotalKm =>
      tramos.fold(0.0, (suma, t) => suma + t.distanciaKm);

  int get duracionTotalMinutos =>
      tramos.fold(0, (suma, t) => suma + t.duracionMinutos);

  String get distanciaTotalFormateada {
    final km = distanciaTotalKm;
    if (km == 0) return '--';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  String get duracionTotalFormateada {
    final min = duracionTotalMinutos;
    if (min == 0) return '--';
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  /// Tiempo sugerido total en todas las atracciones del itinerario
  int get tiempoEstadiaTotalMinutos =>
      destinos.fold(0, (suma, d) => suma + d.tiempoVisitaMinutos);

  /// Tiempo estimado total del tour completo (viaje en ruta + estadía en lugares)
  int get tiempoTotalTourMinutos =>
      duracionTotalMinutos + tiempoEstadiaTotalMinutos;

  String get tiempoEstadiaTotalFormateada {
    final min = tiempoEstadiaTotalMinutos;
    if (min == 0) return '--';
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  String get tiempoTotalTourFormateado {
    final min = tiempoTotalTourMinutos;
    if (min == 0) return '--';
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  bool get tieneAlgunSimulado =>
      tramos.any((t) => t.fuenteRuta == FuenteRuta.simulada);

  ItinerarioViaje copyWith({
    String? titulo,
    List<PuntoItinerario>? puntos,
    List<TramoRuta>? tramos,
  }) =>
      ItinerarioViaje(
        id: id,
        titulo: titulo ?? this.titulo,
        puntos: puntos ?? this.puntos,
        tramos: tramos ?? this.tramos,
        fechaCreacion: fechaCreacion,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'puntos': puntos.map((p) => p.toJson()).toList(),
        'tramos': tramos.map((t) => t.toJson()).toList(),
        'fechaCreacion': fechaCreacion.toIso8601String(),
      };

  factory ItinerarioViaje.fromJson(Map<String, dynamic> json) =>
      ItinerarioViaje(
        id: json['id'] as String,
        titulo: json['titulo'] as String,
        puntos: (json['puntos'] as List)
            .map((p) => PuntoItinerario.fromJson(p as Map<String, dynamic>))
            .toList(),
        tramos: (json['tramos'] as List)
            .map((t) => TramoRuta.fromJson(t as Map<String, dynamic>))
            .toList(),
        fechaCreacion: DateTime.parse(json['fechaCreacion'] as String),
      );

  /// Crea un itinerario vacío listo para usar
  factory ItinerarioViaje.nuevo() => ItinerarioViaje(
        id: 'itinerario_${DateTime.now().millisecondsSinceEpoch}',
        titulo: 'Mi itinerario',
        puntos: [DestinosPredefinidos.origenPredeterminado],
        tramos: [],
        fechaCreacion: DateTime.now(),
      );
}
