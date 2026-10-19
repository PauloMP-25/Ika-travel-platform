import 'horario_modelo.dart';

/// Tipo de alternativa sugerida
enum TipoAlternativa {
  otraActividadMismoDestino,
  mismoDestinoOtroHorario,
  otroDestinoCercano;

  String get etiqueta {
    switch (this) {
      case TipoAlternativa.otraActividadMismoDestino:
        return 'Actividad alternativa';
      case TipoAlternativa.mismoDestinoOtroHorario:
        return 'Mejor ventana horaria';
      case TipoAlternativa.otroDestinoCercano:
        return 'Destino alternativo';
    }
  }
}

/// Modelo de Alternativa Recomendada (Requerimientos 1, 13 y 3)
class AlternativaRecomendada {
  final String id;
  final String tituloActividad;
  final String destino;
  final String imagen;
  final TipoAlternativa tipoAlternativa;
  final String motivoRecomendacion;
  final String condicionesQueJustifican;
  final String? mejorHorarioSugerido;
  final HorarioAtencion? horarioAtencion;
  final String descripcionLugar;
  final String temperaturaActual;
  final String vientoActual;
  final String estadoClima;
  final double latitud;
  final double longitud;
  final bool esMock;

  const AlternativaRecomendada({
    required this.id,
    required this.tituloActividad,
    required this.destino,
    required this.imagen,
    required this.tipoAlternativa,
    required this.motivoRecomendacion,
    required this.condicionesQueJustifican,
    this.mejorHorarioSugerido,
    this.horarioAtencion,
    this.descripcionLugar = '',
    this.temperaturaActual = '24°C',
    this.vientoActual = '12 km/h',
    this.estadoClima = 'Favorable',
    this.latitud = -14.0678,
    this.longitud = -75.7286,
    this.esMock = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tituloActividad': tituloActividad,
        'destino': destino,
        'imagen': imagen,
        'tipoAlternativa': tipoAlternativa.name,
        'motivoRecomendacion': motivoRecomendacion,
        'condicionesQueJustifican': condicionesQueJustifican,
        'mejorHorarioSugerido': mejorHorarioSugerido,
        'horarioAtencion': horarioAtencion?.toJson(),
        'descripcionLugar': descripcionLugar,
        'temperaturaActual': temperaturaActual,
        'vientoActual': vientoActual,
        'estadoClima': estadoClima,
        'latitud': latitud,
        'longitud': longitud,
        'esMock': esMock,
      };

  factory AlternativaRecomendada.fromJson(Map<String, dynamic> json) {
    return AlternativaRecomendada(
      id: json['id'] ?? '',
      tituloActividad: json['tituloActividad'] ?? '',
      destino: json['destino'] ?? 'Ica',
      imagen: json['imagen'] ?? 'assets/images/act_vinos.jpg',
      tipoAlternativa: TipoAlternativa.values.firstWhere(
        (t) => t.name == json['tipoAlternativa'],
        orElse: () => TipoAlternativa.otraActividadMismoDestino,
      ),
      motivoRecomendacion: json['motivoRecomendacion'] ?? '',
      condicionesQueJustifican: json['condicionesQueJustifican'] ?? '',
      mejorHorarioSugerido: json['mejorHorarioSugerido'],
      horarioAtencion: json['horarioAtencion'] != null
          ? HorarioAtencion.fromJson(json['horarioAtencion'] as Map<String, dynamic>)
          : null,
      descripcionLugar: json['descripcionLugar'] ?? '',
      temperaturaActual: json['temperaturaActual'] ?? '24°C',
      vientoActual: json['vientoActual'] ?? '12 km/h',
      estadoClima: json['estadoClima'] ?? 'Favorable',
      latitud: (json['latitud'] as num?)?.toDouble() ?? -14.0678,
      longitud: (json['longitud'] as num?)?.toDouble() ?? -75.7286,
      esMock: json['esMock'] ?? true,
    );
  }
}
