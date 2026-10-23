import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Tipos de maniobras reconocidas por OSRM (Open Source Routing Machine)
enum TipoManiobra {
  depart, // Salida / Inicio
  arrive, // Llegada a destino
  turn, // Giro convencional
  newName, // Cambio de nombre de vía sin giro
  continueStraight, // Continuar recto
  roundabout, // Rotonda / óvalo
  rotary, // Rotonda grande
  roundaboutTurn,
  merge, // Incorporación a vía
  fork, // Bifurcación
  onRamp, // Rampa de subida
  offRamp, // Rampa de salida
  endOfRoad, // Fin de camino (obligado a doblar)
  desconocido,
}

/// Modificadores de dirección para la maniobra
enum ModificadorManiobra {
  uturn, // Giro en U
  sharpRight, // Giro pronunciado derecha
  right, // Giro normal derecha
  slightRight, // Giro suave derecha
  straight, // Recto
  slightLeft, // Giro suave izquierda
  left, // Giro normal izquierda
  sharpLeft, // Giro pronunciado izquierda
  ninguno,
}

/// Estado del sensor GPS y permisos del dispositivo
enum EstadoGPS {
  iniciando,
  activo,
  buscandoSenal,
  desactivado,
  permisoDenegado,
  permisoDenegadoPermanente,
  errorConexion,
  modoSimulacionPrueba,
}

/// Representa una maniobra de navegación
class ManiobraPaso {
  final TipoManiobra tipo;
  final ModificadorManiobra modificador;
  final LatLng ubicacion;
  final double? rumboAntes;
  final double? rumboDespues;

  const ManiobraPaso({
    required this.tipo,
    required this.modificador,
    required this.ubicacion,
    this.rumboAntes,
    this.rumboDespues,
  });

  factory ManiobraPaso.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?)?.toLowerCase() ?? '';
    final modStr = (json['modifier'] as String?)?.toLowerCase() ?? '';
    final locList = (json['location'] as List?) ?? [0.0, 0.0];

    final tipo = switch (typeStr) {
      'depart' => TipoManiobra.depart,
      'arrive' => TipoManiobra.arrive,
      'turn' => TipoManiobra.turn,
      'new name' => TipoManiobra.newName,
      'continue' => TipoManiobra.continueStraight,
      'roundabout' => TipoManiobra.roundabout,
      'rotary' => TipoManiobra.rotary,
      'roundabout turn' => TipoManiobra.roundaboutTurn,
      'merge' => TipoManiobra.merge,
      'fork' => TipoManiobra.fork,
      'on ramp' => TipoManiobra.onRamp,
      'off ramp' => TipoManiobra.offRamp,
      'end of road' => TipoManiobra.endOfRoad,
      _ => TipoManiobra.desconocido,
    };

    final mod = switch (modStr) {
      'uturn' => ModificadorManiobra.uturn,
      'sharp right' => ModificadorManiobra.sharpRight,
      'right' => ModificadorManiobra.right,
      'slight right' => ModificadorManiobra.slightRight,
      'straight' => ModificadorManiobra.straight,
      'slight left' => ModificadorManiobra.slightLeft,
      'left' => ModificadorManiobra.left,
      'sharp left' => ModificadorManiobra.sharpLeft,
      _ => ModificadorManiobra.ninguno,
    };

    return ManiobraPaso(
      tipo: tipo,
      modificador: mod,
      ubicacion: LatLng(
        (locList[1] as num).toDouble(),
        (locList[0] as num).toDouble(),
      ),
      rumboAntes: (json['bearing_before'] as num?)?.toDouble(),
      rumboDespues: (json['bearing_after'] as num?)?.toDouble(),
    );
  }
}

/// Un paso individual de navegación (giro, avance o llegada)
class PasoNavegacion {
  final String id;
  final String nombreVia;
  final double distanciaMetros;
  final double duracionSegundos;
  final String instruccionEspanol;
  final ManiobraPaso maniobra;
  final List<LatLng> geometria;
  final IconData iconoManiobra;

  const PasoNavegacion({
    required this.id,
    required this.nombreVia,
    required this.distanciaMetros,
    required this.duracionSegundos,
    required this.instruccionEspanol,
    required this.maniobra,
    required this.geometria,
    required this.iconoManiobra,
  });

  String get distanciaFormateada {
    if (distanciaMetros < 1000) {
      return '${distanciaMetros.round()} m';
    }
    return '${(distanciaMetros / 1000).toStringAsFixed(1)} km';
  }
}

/// Modelo integral de una ruta preparada para navegación vehicular
class RutaNavegacion {
  final String id;
  final String etiqueta;
  final LatLng origen;
  final LatLng destino;
  final String nombreDestino;
  final List<LatLng> polilineaCompleta;
  final List<PasoNavegacion> pasos;
  final double distanciaTotalMetros;
  final double duracionTotalSegundos;
  final bool esSimulada;
  final bool esSeleccionada;
  final String? resumenVia;

  const RutaNavegacion({
    this.id = 'ruta_0',
    this.etiqueta = 'Ruta principal',
    required this.origen,
    required this.destino,
    required this.nombreDestino,
    required this.polilineaCompleta,
    required this.pasos,
    required this.distanciaTotalMetros,
    required this.duracionTotalSegundos,
    this.esSimulada = false,
    this.esSeleccionada = true,
    this.resumenVia,
  });

  String get distanciaTotalFormateada {
    final km = distanciaTotalMetros / 1000.0;
    if (km < 1) return '${distanciaTotalMetros.round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  String get duracionTotalFormateada {
    final minutos = (duracionTotalSegundos / 60.0).round();
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m == 0 ? '${h} h' : '${h} h ${m} min';
  }

  RutaNavegacion copyWith({
    String? id,
    String? etiqueta,
    LatLng? origen,
    LatLng? destino,
    String? nombreDestino,
    List<LatLng>? polilineaCompleta,
    List<PasoNavegacion>? pasos,
    double? distanciaTotalMetros,
    double? duracionTotalSegundos,
    bool? esSimulada,
    bool? esSeleccionada,
    String? resumenVia,
  }) {
    return RutaNavegacion(
      id: id ?? this.id,
      etiqueta: etiqueta ?? this.etiqueta,
      origen: origen ?? this.origen,
      destino: destino ?? this.destino,
      nombreDestino: nombreDestino ?? this.nombreDestino,
      polilineaCompleta: polilineaCompleta ?? this.polilineaCompleta,
      pasos: pasos ?? this.pasos,
      distanciaTotalMetros: distanciaTotalMetros ?? this.distanciaTotalMetros,
      duracionTotalSegundos:
          duracionTotalSegundos ?? this.duracionTotalSegundos,
      esSimulada: esSimulada ?? this.esSimulada,
      esSeleccionada: esSeleccionada ?? this.esSeleccionada,
      resumenVia: resumenVia ?? this.resumenVia,
    );
  }
}

