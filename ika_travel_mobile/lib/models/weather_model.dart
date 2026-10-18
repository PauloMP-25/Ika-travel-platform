class ClimaActualModel {
  final double temperaturaActual;
  final double sensacionTermica;
  final double probabilidadPrecipitacion;
  final double humedad;
  final double velocidadViento;
  final double? rafagasViento;
  final double indiceUv;
  final String descripcionClima;
  final double visibilidad;
  final String destino;
  final bool isCached;

  const ClimaActualModel({
    required this.temperaturaActual,
    required this.sensacionTermica,
    required this.probabilidadPrecipitacion,
    required this.humedad,
    required this.velocidadViento,
    this.rafagasViento,
    required this.indiceUv,
    required this.descripcionClima,
    required this.visibilidad,
    required this.destino,
    this.isCached = false,
  });

  factory ClimaActualModel.fromJson(Map<String, dynamic> json) {
    return ClimaActualModel(
      temperaturaActual: (json['temperatura_actual'] as num?)?.toDouble() ?? 26.0,
      sensacionTermica: (json['sensacion_termica'] as num?)?.toDouble() ?? 26.0,
      probabilidadPrecipitacion: (json['probabilidad_precipitacion'] as num?)?.toDouble() ?? 0.0,
      humedad: (json['humedad'] as num?)?.toDouble() ?? 50.0,
      velocidadViento: (json['velocidad_viento'] as num?)?.toDouble() ?? 12.0,
      rafagasViento: (json['rafagas_viento'] as num?)?.toDouble(),
      indiceUv: (json['indice_uv'] as num?)?.toDouble() ?? 5.0,
      descripcionClima: json['descripcion_clima'] as String? ?? 'Despejado',
      visibilidad: (json['visibilidad'] as num?)?.toDouble() ?? 10.0,
      destino: json['destino'] as String? ?? 'Ica',
      isCached: json['is_cached'] as bool? ?? false,
    );
  }

  String get nivelUv {
    if (indiceUv <= 2) return 'Bajo';
    if (indiceUv <= 5) return 'Moderado';
    if (indiceUv <= 7) return 'Alto';
    if (indiceUv <= 10) return 'Muy Alto';
    return 'Extremo';
  }
}

class PronosticoHoraModel {
  final DateTime time;
  final double temperature;
  final double uvIndex;
  final double windSpeed;
  final double precipitationProbability;
  final String condition;

  const PronosticoHoraModel({
    required this.time,
    required this.temperature,
    required this.uvIndex,
    required this.windSpeed,
    required this.precipitationProbability,
    required this.condition,
  });

  factory PronosticoHoraModel.fromJson(Map<String, dynamic> json) {
    return PronosticoHoraModel(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 20.0,
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 1.0,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 10.0,
      precipitationProbability: (json['precipitation_probability'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition'] as String? ?? 'Despejado',
    );
  }

  String get horaFormato {
    final hora = time.hour.toString().padLeft(2, '0');
    final minutos = time.minute.toString().padLeft(2, '0');
    return '$hora:$minutos';
  }
}

class PronosticoDiaModel {
  final String date;
  final double tempMin;
  final double tempMax;
  final double uvIndexMax;
  final double windSpeedMax;
  final double precipitationSum;
  final double precipitationProbabilityMax;
  final String condition;

  const PronosticoDiaModel({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.uvIndexMax,
    required this.windSpeedMax,
    required this.precipitationSum,
    required this.precipitationProbabilityMax,
    required this.condition,
  });

  factory PronosticoDiaModel.fromJson(Map<String, dynamic> json) {
    return PronosticoDiaModel(
      date: json['date'] as String? ?? '',
      tempMin: (json['temp_min'] as num?)?.toDouble() ?? 15.0,
      tempMax: (json['temp_max'] as num?)?.toDouble() ?? 27.0,
      uvIndexMax: (json['uv_index_max'] as num?)?.toDouble() ?? 5.0,
      windSpeedMax: (json['wind_speed_max'] as num?)?.toDouble() ?? 15.0,
      precipitationSum: (json['precipitation_sum'] as num?)?.toDouble() ?? 0.0,
      precipitationProbabilityMax: (json['precipitation_probability_max'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition'] as String? ?? 'Soleado',
    );
  }
}

class PronosticoCompletoModel {
  final String destino;
  final List<PronosticoHoraModel> horas;
  final List<PronosticoDiaModel> dias;

  const PronosticoCompletoModel({
    required this.destino,
    required this.horas,
    required this.dias,
  });

  factory PronosticoCompletoModel.fromJson(Map<String, dynamic> json) {
    final listHoras = (json['horas'] as List<dynamic>? ?? [])
        .map((e) => PronosticoHoraModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final listDias = (json['dias'] as List<dynamic>? ?? [])
        .map((e) => PronosticoDiaModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PronosticoCompletoModel(
      destino: json['destino'] as String? ?? 'Ica',
      horas: listHoras,
      dias: listDias,
    );
  }
}
