/// Horario específico para un día o rango de días
class HorarioDia {
  final String dia;
  final String horario;
  final String? nota;

  const HorarioDia({
    required this.dia,
    required this.horario,
    this.nota,
  });

  Map<String, dynamic> toJson() => {
        'dia': dia,
        'horario': horario,
        'nota': nota,
      };

  factory HorarioDia.fromJson(Map<String, dynamic> json) => HorarioDia(
        dia: json['dia'] ?? '',
        horario: json['horario'] ?? '',
        nota: json['nota'],
      );
}

/// Modelo de Horario de Atención y Días Disponibles (Requerimiento 3)
class HorarioAtencion {
  final String diasSemana;
  final String horarioGeneral;
  final String estadoVerificacion; // "Horario referencial", "Horario no confirmado", "Horario verificado SERNANP"
  final bool esVerificado;
  final String observaciones;
  final List<HorarioDia> horariosPorDia;

  const HorarioAtencion({
    required this.diasSemana,
    required this.horarioGeneral,
    required this.estadoVerificacion,
    required this.esVerificado,
    required this.observaciones,
    this.horariosPorDia = const [],
  });

  Map<String, dynamic> toJson() => {
        'diasSemana': diasSemana,
        'horarioGeneral': horarioGeneral,
        'estadoVerificacion': estadoVerificacion,
        'esVerificado': esVerificado,
        'observaciones': observaciones,
        'horariosPorDia': horariosPorDia.map((h) => h.toJson()).toList(),
      };

  factory HorarioAtencion.fromJson(Map<String, dynamic> json) => HorarioAtencion(
        diasSemana: json['diasSemana'] ?? 'Lunes a Domingo',
        horarioGeneral: json['horarioGeneral'] ?? 'Horario no confirmado',
        estadoVerificacion: json['estadoVerificacion'] ?? 'Horario no confirmado',
        esVerificado: json['esVerificado'] ?? false,
        observaciones: json['observaciones'] ?? '',
        horariosPorDia: (json['horariosPorDia'] as List<dynamic>?)
                ?.map((e) => HorarioDia.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  // Catálogo de horarios predeterminados fieles a la realidad turística de Ica
  static HorarioAtencion paraHuacachina() {
    return const HorarioAtencion(
      diasSemana: 'Lunes a Domingo (Todo el año)',
      horarioGeneral: '07:30 - 18:30 hrs',
      estadoVerificacion: 'Horario referencial',
      esVerificado: false,
      observaciones:
          'Operadores turísticos de tubulares y sandboarding en el oasis. Último turno recomendado a las 16:30 para presenciar el atardecer en las dunas.',
      horariosPorDia: [
        HorarioDia(
          dia: 'Lunes a Viernes',
          horario: '08:00 - 18:00',
          nota: 'Menor afluencia turística; salidas flexibles.',
        ),
        HorarioDia(
          dia: 'Sábados, Domingos y Feriados',
          horario: '07:30 - 18:30',
          nota: 'Alta demanda en dunas; se recomienda turno matutino (08:00 - 10:30) para evitar colas y viento térmico.',
        ),
      ],
    );
  }

  static HorarioAtencion paraIslasBallestas() {
    return const HorarioAtencion(
      diasSemana: 'Lunes a Domingo',
      horarioGeneral: '07:30 - 11:30 hrs (Zarpes en la mañana)',
      estadoVerificacion: 'Horario referencial (Sujeto a Capitanía)',
      esVerificado: true,
      observaciones:
          'Solo se realizan zarpes durante la mañana para evitar los fuertes vientos Paracas de la tarde. Horarios estrictamente condicionados a la apertura del muelle por la Capitanía de Puerto de Pisco.',
      horariosPorDia: [
        HorarioDia(
          dia: 'Primer turno matutino',
          horario: '08:00 AM',
          nota: 'Condición de mar habitualmente más calmo. Ideal para observación de lobos marinos.',
        ),
        HorarioDia(
          dia: 'Segundo turno',
          horario: '10:00 AM',
          nota: 'Mayor temperatura ambiental; sujeto a estado de oleaje.',
        ),
        HorarioDia(
          dia: 'Turno especial (Feriados / Alta demanda)',
          horario: '11:30 AM',
          nota: 'Sujeto a confirmación naval diaria.',
        ),
      ],
    );
  }

  static HorarioAtencion paraReservaParacas() {
    return const HorarioAtencion(
      diasSemana: 'Lunes a Domingo (Incluye feriados)',
      horarioGeneral: '08:00 - 17:00 hrs',
      estadoVerificacion: 'Horario verificado SERNANP',
      esVerificado: true,
      observaciones:
          'Control de acceso vehicular en garita SERNANP. El Centro de Interpretación de Paracas atiende de 09:00 a 16:00 hrs. Prohibido acampar sin autorización en zonas protegidas.',
      horariosPorDia: [
        HorarioDia(
          dia: 'Todos los días (Garita)',
          horario: '08:00 - 17:00',
          nota: 'Ingreso a miradores de La Catedral, Playa Roja y Yumaque.',
        ),
        HorarioDia(
          dia: 'Centro de Interpretación',
          horario: '09:00 - 16:00',
          nota: 'Museo de sitio de biodiversidad marina.',
        ),
      ],
    );
  }

  static HorarioAtencion paraVinedos() {
    return const HorarioAtencion(
      diasSemana: 'Martes a Domingo',
      horarioGeneral: '09:00 - 17:30 hrs',
      estadoVerificacion: 'Horario referencial',
      esVerificado: false,
      observaciones:
          'La mayoría de bodegas patrimoniales (Tacama, Vista Alegre, El Catador) descansan los días lunes para labores agrícolas. Recorridos y catas guiadas se inician cada 45 minutos.',
      horariosPorDia: [
        HorarioDia(
          dia: 'Martes a Viernes',
          horario: '09:30 - 17:00',
          nota: 'Tours guiados por viñedos y bodegas industriales/artesanales.',
        ),
        HorarioDia(
          dia: 'Sábados, Domingos y Feriados',
          horario: '09:00 - 18:00',
          nota: 'Servicio de restaurante campestre, maridajes y presentaciones de caballos de paso.',
        ),
        HorarioDia(
          dia: 'Lunes',
          horario: 'Cerrado / Mantenimiento',
          nota: 'Solo algunas tiendas de licores atienden al público.',
        ),
      ],
    );
  }

  static HorarioAtencion paraLuren() {
    return const HorarioAtencion(
      diasSemana: 'Lunes a Domingo',
      horarioGeneral: '07:00 - 20:00 hrs',
      estadoVerificacion: 'Horario oficial Diócesis de Ica',
      esVerificado: true,
      observaciones: 'Misas diarias y atención al peregrino en el Santuario.',
      horariosPorDia: [
        HorarioDia(dia: 'Todos los días', horario: '07:00 - 20:00', nota: 'Templo abierto.'),
      ],
    );
  }

  static HorarioAtencion noConfirmado() {
    return const HorarioAtencion(
      diasSemana: 'Consultar con operador local',
      horarioGeneral: 'Horario no confirmado',
      estadoVerificacion: 'Horario no confirmado',
      esVerificado: false,
      observaciones:
          'No se dispone de información oficial verificada para este punto turístico. Se aconseja contactar al operador o guía antes de la visita.',
      horariosPorDia: [],
    );
  }
}
