import 'package:flutter/material.dart';
import 'horario_modelo.dart';

/// Estado de aptitud de una actividad turística según el clima actual
enum EstadoAptitud {
  optima,
  precaucion,
  noRecomendada,
  suspendida;

  String get etiqueta {
    switch (this) {
      case EstadoAptitud.optima:
        return 'Condición óptima';
      case EstadoAptitud.precaucion:
        return 'Realizar con precaución';
      case EstadoAptitud.noRecomendada:
        return 'No recomendada';
      case EstadoAptitud.suspendida:
        return 'Operación suspendida';
    }
  }

  Color get color {
    switch (this) {
      case EstadoAptitud.optima:
        return const Color(0xFF2E7D32);
      case EstadoAptitud.precaucion:
        return const Color(0xFFE65100);
      case EstadoAptitud.noRecomendada:
        return const Color(0xFFC62828);
      case EstadoAptitud.suspendida:
        return const Color(0xFF5D4037);
    }
  }

  IconData get icono {
    switch (this) {
      case EstadoAptitud.optima:
        return Icons.check_circle_outline;
      case EstadoAptitud.precaucion:
        return Icons.warning_amber_rounded;
      case EstadoAptitud.noRecomendada:
        return Icons.cancel_outlined;
      case EstadoAptitud.suspendida:
        return Icons.block_outlined;
    }
  }
}

/// Aptitud de una actividad específica en un destino
class AptitudActividad {
  final String actividadTitulo;
  final EstadoAptitud estado;
  final String detalleClimatico;

  const AptitudActividad({
    required this.actividadTitulo,
    required this.estado,
    required this.detalleClimatico,
  });

  Map<String, dynamic> toJson() => {
        'actividadTitulo': actividadTitulo,
        'estado': estado.name,
        'detalleClimatico': detalleClimatico,
      };

  factory AptitudActividad.fromJson(Map<String, dynamic> json) {
    return AptitudActividad(
      actividadTitulo: json['actividadTitulo'] ?? '',
      estado: EstadoAptitud.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => EstadoAptitud.optima,
      ),
      detalleClimatico: json['detalleClimatico'] ?? '',
    );
  }
}

/// Registro cronológico de cambio de condición en un destino
class RegistroCambioHistorial {
  final String id;
  final DateTime fechaHora;
  final String parametroModificado;
  final String valorAnterior;
  final String valorActual;
  final String? alertaIdAsociada;
  final String resumenImpacto;

  const RegistroCambioHistorial({
    required this.id,
    required this.fechaHora,
    required this.parametroModificado,
    required this.valorAnterior,
    required this.valorActual,
    this.alertaIdAsociada,
    required this.resumenImpacto,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fechaHora': fechaHora.toIso8601String(),
        'parametroModificado': parametroModificado,
        'valorAnterior': valorAnterior,
        'valorActual': valorActual,
        'alertaIdAsociada': alertaIdAsociada,
        'resumenImpacto': resumenImpacto,
      };

  factory RegistroCambioHistorial.fromJson(Map<String, dynamic> json) {
    return RegistroCambioHistorial(
      id: json['id'] ?? '',
      fechaHora: DateTime.tryParse(json['fechaHora'] ?? '') ?? DateTime.now(),
      parametroModificado: json['parametroModificado'] ?? '',
      valorAnterior: json['valorAnterior'] ?? '',
      valorActual: json['valorActual'] ?? '',
      alertaIdAsociada: json['alertaIdAsociada'],
      resumenImpacto: json['resumenImpacto'] ?? '',
    );
  }
}

/// Modelo de Monitoreo y Seguimiento de Destino (Requerimiento 14)
class DestinoSeguimiento {
  final String id;
  final String nombre;
  final String region;
  final String imagen;
  final DateTime ultimaActualizacion;
  final String estadoGeneral;
  final String temperaturaActual;
  final String vientoActual;
  final String humedadActual;
  final String uvActual;
  final List<AptitudActividad> actividadesAptitud;
  final List<RegistroCambioHistorial> historialCambios;
  final List<String> alertasActivasIds;
  final HorarioAtencion? horarioAtencion;
  final bool esMock;

  const DestinoSeguimiento({
    required this.id,
    required this.nombre,
    required this.region,
    required this.imagen,
    required this.ultimaActualizacion,
    required this.estadoGeneral,
    required this.temperaturaActual,
    required this.vientoActual,
    required this.humedadActual,
    required this.uvActual,
    required this.actividadesAptitud,
    required this.historialCambios,
    required this.alertasActivasIds,
    this.horarioAtencion,
    this.esMock = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'region': region,
        'imagen': imagen,
        'ultimaActualizacion': ultimaActualizacion.toIso8601String(),
        'estadoGeneral': estadoGeneral,
        'temperaturaActual': temperaturaActual,
        'vientoActual': vientoActual,
        'humedadActual': humedadActual,
        'uvActual': uvActual,
        'actividadesAptitud': actividadesAptitud.map((a) => a.toJson()).toList(),
        'historialCambios': historialCambios.map((h) => h.toJson()).toList(),
        'alertasActivasIds': alertasActivasIds,
        'horarioAtencion': horarioAtencion?.toJson(),
        'esMock': esMock,
      };

  factory DestinoSeguimiento.fromJson(Map<String, dynamic> json) {
    return DestinoSeguimiento(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      region: json['region'] ?? 'Ica, Perú',
      imagen: json['imagen'] ?? 'assets/images/carrusel_1_huacachina.jpg',
      ultimaActualizacion: DateTime.tryParse(json['ultimaActualizacion'] ?? '') ?? DateTime.now(),
      estadoGeneral: json['estadoGeneral'] ?? 'Condiciones normales',
      temperaturaActual: json['temperaturaActual'] ?? '24°C',
      vientoActual: json['vientoActual'] ?? '15 km/h',
      humedadActual: json['humedadActual'] ?? '50%',
      uvActual: json['uvActual'] ?? 'Moderado',
      actividadesAptitud: (json['actividadesAptitud'] as List<dynamic>?)
              ?.map((a) => AptitudActividad.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      historialCambios: (json['historialCambios'] as List<dynamic>?)
              ?.map((h) => RegistroCambioHistorial.fromJson(h as Map<String, dynamic>))
              .toList() ??
          [],
      alertasActivasIds: (json['alertasActivasIds'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          [],
      horarioAtencion: json['horarioAtencion'] != null
          ? HorarioAtencion.fromJson(json['horarioAtencion'] as Map<String, dynamic>)
          : null,
      esMock: json['esMock'] ?? true,
    );
  }
}
