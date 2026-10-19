import 'package:flutter/material.dart';

/// Niveles de riesgo con criterios estandarizados
enum NivelRiesgo {
  informativo,
  precaucion,
  alto,
  critico;

  String get etiqueta {
    switch (this) {
      case NivelRiesgo.informativo:
        return 'Informativo';
      case NivelRiesgo.precaucion:
        return 'Precaución';
      case NivelRiesgo.alto:
        return 'Riesgo Alto';
      case NivelRiesgo.critico:
        return 'Peligro Crítico';
    }
  }

  Color get color {
    switch (this) {
      case NivelRiesgo.informativo:
        return const Color(0xFF2E7D32); // Verde oscuro
      case NivelRiesgo.precaucion:
        return const Color(0xFFE65100); // Ámbar / naranja
      case NivelRiesgo.alto:
        return const Color(0xFFC62828); // Rojo
      case NivelRiesgo.critico:
        return const Color(0xFF6A1B9A); // Púrpura intenso
    }
  }

  Color get colorFondo {
    switch (this) {
      case NivelRiesgo.informativo:
        return const Color(0xFFE8F5E9);
      case NivelRiesgo.precaucion:
        return const Color(0xFFFFF3E0);
      case NivelRiesgo.alto:
        return const Color(0xFFFFEBEE);
      case NivelRiesgo.critico:
        return const Color(0xFFF3E5F5);
    }
  }

  IconData get icono {
    switch (this) {
      case NivelRiesgo.informativo:
        return Icons.info_outline;
      case NivelRiesgo.precaucion:
        return Icons.warning_amber_rounded;
      case NivelRiesgo.alto:
        return Icons.report_problem_rounded;
      case NivelRiesgo.critico:
        return Icons.dangerous_rounded;
    }
  }
}

/// Métrica puntual de clima con unidad y valor
class MetricaClima {
  final String nombre;
  final String valor;
  final String unidad;
  final IconData icono;

  const MetricaClima({
    required this.nombre,
    required this.valor,
    required this.unidad,
    required this.icono,
  });

  String get valorConUnidad => unidad.isNotEmpty ? '$valor $unidad' : valor;

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'valor': valor,
        'unidad': unidad,
      };

  factory MetricaClima.fromJson(Map<String, dynamic> json) {
    IconData iconData = Icons.device_thermostat;
    final nombre = json['nombre'] as String? ?? '';
    if (nombre.toLowerCase().contains('viento')) iconData = Icons.air;
    if (nombre.toLowerCase().contains('lluvia')) iconData = Icons.water_drop_outlined;
    if (nombre.toLowerCase().contains('uv')) iconData = Icons.wb_sunny_outlined;
    if (nombre.toLowerCase().contains('mar') || nombre.toLowerCase().contains('oleaje')) {
      iconData = Icons.waves;
    }

    return MetricaClima(
      nombre: nombre,
      valor: json['valor']?.toString() ?? '',
      unidad: json['unidad'] as String? ?? '',
      icono: iconData,
    );
  }
}

/// Snapshot de condiciones en un momento dado
class CondicionClima {
  final DateTime fechaHora;
  final String estadoCielo;
  final String temperatura;
  final String velocidadViento;
  final String probabilidadLluvia;
  final String indiceUv;
  final String estadoMar;
  final List<MetricaClima> metricasDetalladas;

  const CondicionClima({
    required this.fechaHora,
    required this.estadoCielo,
    required this.temperatura,
    required this.velocidadViento,
    required this.probabilidadLluvia,
    required this.indiceUv,
    this.estadoMar = 'Calmado',
    this.metricasDetalladas = const [],
  });

  Map<String, dynamic> toJson() => {
        'fechaHora': fechaHora.toIso8601String(),
        'estadoCielo': estadoCielo,
        'temperatura': temperatura,
        'velocidadViento': velocidadViento,
        'probabilidadLluvia': probabilidadLluvia,
        'indiceUv': indiceUv,
        'estadoMar': estadoMar,
        'metricasDetalladas': metricasDetalladas.map((m) => m.toJson()).toList(),
      };

  factory CondicionClima.fromJson(Map<String, dynamic> json) {
    return CondicionClima(
      fechaHora: DateTime.tryParse(json['fechaHora'] ?? '') ?? DateTime.now(),
      estadoCielo: json['estadoCielo'] ?? 'Despejado',
      temperatura: json['temperatura'] ?? '24°C',
      velocidadViento: json['velocidadViento'] ?? '15 km/h',
      probabilidadLluvia: json['probabilidadLluvia'] ?? '0%',
      indiceUv: json['indiceUv'] ?? 'Moderado',
      estadoMar: json['estadoMar'] ?? 'Calmado',
      metricasDetalladas: (json['metricasDetalladas'] as List<dynamic>?)
              ?.map((m) => MetricaClima.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Modelo completo de Alerta Inteligente
class AlertaClima {
  final String id;
  final String titulo;
  final String destino;
  final String actividad;
  final DateTime fechaHora;
  final NivelRiesgo nivelRiesgo;
  final String motivoCambio;
  final String impactoActividad;
  final CondicionClima condicionAnterior;
  final CondicionClima condicionActual;
  final List<String> recomendacionesSeguridad;
  final bool esMock;
  final bool activa;

  const AlertaClima({
    required this.id,
    required this.titulo,
    required this.destino,
    required this.actividad,
    required this.fechaHora,
    required this.nivelRiesgo,
    required this.motivoCambio,
    required this.impactoActividad,
    required this.condicionAnterior,
    required this.condicionActual,
    required this.recomendacionesSeguridad,
    this.esMock = true,
    this.activa = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'destino': destino,
        'actividad': actividad,
        'fechaHora': fechaHora.toIso8601String(),
        'nivelRiesgo': nivelRiesgo.name,
        'motivoCambio': motivoCambio,
        'impactoActividad': impactoActividad,
        'condicionAnterior': condicionAnterior.toJson(),
        'condicionActual': condicionActual.toJson(),
        'recomendacionesSeguridad': recomendacionesSeguridad,
        'esMock': esMock,
        'activa': activa,
      };

  factory AlertaClima.fromJson(Map<String, dynamic> json) {
    return AlertaClima(
      id: json['id'] ?? '',
      titulo: json['titulo'] ?? '',
      destino: json['destino'] ?? 'Ica',
      actividad: json['actividad'] ?? '',
      fechaHora: DateTime.tryParse(json['fechaHora'] ?? '') ?? DateTime.now(),
      nivelRiesgo: NivelRiesgo.values.firstWhere(
        (r) => r.name == json['nivelRiesgo'],
        orElse: () => NivelRiesgo.precaucion,
      ),
      motivoCambio: json['motivoCambio'] ?? '',
      impactoActividad: json['impactoActividad'] ?? '',
      condicionAnterior: CondicionClima.fromJson(json['condicionAnterior'] ?? {}),
      condicionActual: CondicionClima.fromJson(json['condicionActual'] ?? {}),
      recomendacionesSeguridad: (json['recomendacionesSeguridad'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      esMock: json['esMock'] ?? true,
      activa: json['activa'] ?? true,
    );
  }
}
