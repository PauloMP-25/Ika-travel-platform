import '../models/alerta_modelo.dart';
import '../models/alternativa_modelo.dart';
import '../models/horario_modelo.dart';

/// Servicio de alternativas inteligentes recomendadas (Requerimientos 1, 13 y 3)
/// Basado en el catálogo existente de actividades y destinos en Ika Travel.
class RecomendadorService {
  static final RecomendadorService _instancia = RecomendadorService._interno();
  factory RecomendadorService() => _instancia;
  RecomendadorService._interno();

  /// Obtiene alternativas pertinentes ante una alerta climática desfavorable
  List<AlternativaRecomendada> obtenerAlternativasParaAlerta(AlertaClima alerta) {
    final actividadLimpia = alerta.actividad.replaceAll('\n', ' ').trim();
    final List<AlternativaRecomendada> alternativas = [];

    // CASO 1: Viento fuerte en Huacachina (Sandboarding o Buggies en dunas)
    if (actividadLimpia.contains('Sandboarding') || actividadLimpia.contains('buggy')) {
      // 1.1 Actividad alternativa resguardada en Ica: Viñedos y bodegas
      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_vinos_01',
          tituloActividad: 'Viñedos y bodegas',
          destino: 'Ica',
          imagen: 'assets/images/act_vinos.jpg',
          tipoAlternativa: TipoAlternativa.otraActividadMismoDestino,
          motivoRecomendacion:
              'Ambiente campestre protegido con zonas techadas, bodegas subterráneas y salas de cata inmunes al viento desértico.',
          condicionesQueJustifican:
              'Temperatura agradable de 24°C, velocidad de viento de solo 11 km/h y sombra arbolada en el valle vitivinícola.',
          mejorHorarioSugerido: '11:30 AM a 04:00 PM (Horas de mayor viento en el desierto)',
          horarioAtencion: HorarioAtencion.paraVinedos(),
          descripcionLugar:
              'Recorrido por las campiñas vitivinícolas más antiguas de América del Sur. Conoce el proceso de destilación del pisco peruano, disfruta de catas guiadas y gastronomía típica en amplios comedores al aire libre protegidos del viento.',
          temperaturaActual: '24°C',
          vientoActual: '11 km/h',
          estadoClima: 'Soleado y templado',
          latitud: -14.0450,
          longitud: -75.7280,
          esMock: true,
        ),
      );

      // 1.2 Mismo destino en mejor ventana horaria
      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_sand_horario_02',
          tituloActividad: 'Sandboarding en Huacachina (Turno Matutino)',
          destino: 'Huacachina',
          imagen: 'assets/images/detalle_sandboarding_1.jpg',
          tipoAlternativa: TipoAlternativa.mismoDestinoOtroHorario,
          motivoRecomendacion:
              'El fenómeno de viento Paracas suele amainar al amanecer. Las primeras horas de la mañana presentan arena firme y visibilidad total.',
          condicionesQueJustifican:
              'Pronóstico matutino con vientos promedio de 8 a 12 km/h y temperatura fresca de 19°C.',
          mejorHorarioSugerido: 'Mañana entre 08:00 AM y 10:30 AM',
          horarioAtencion: HorarioAtencion.paraHuacachina(),
          descripcionLugar:
              'El oasis de Huacachina rodeado de imponentes dunas de arena. Por la mañana la arena conserva frescura, las ráfagas son mínimas y los descensos en tabla son fluidos y seguros.',
          temperaturaActual: '19°C (Proyectada)',
          vientoActual: '9 km/h',
          estadoClima: 'Cielo despejado sin polvo',
          latitud: -14.0875,
          longitud: -75.7628,
          esMock: true,
        ),
      );

      // 1.3 Destino alternativo: Reserva Nacional de Paracas
      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_reserva_03',
          tituloActividad: 'Reserva Nacional de Paracas',
          destino: 'Paracas',
          imagen: 'assets/images/act_reserva1.jpg',
          tipoAlternativa: TipoAlternativa.otroDestinoCercano,
          motivoRecomendacion:
              'Circuito terrestre vehicular y miradores de costa acantilada protegidos de tolvaneras.',
          condicionesQueJustifican:
              'A 1 hora y 15 min de Ica. Clima fresco de 20°C con carreteras asfaltadas sin arena suelta en calzada.',
          mejorHorarioSugerido: '09:00 AM a 02:00 PM',
          horarioAtencion: HorarioAtencion.paraReservaParacas(),
          descripcionLugar:
              'Área natural protegida costera con vistas panorámicas a acantilados, playas de arena rojiza como Playa Roja y formaciones fósiles en el desierto marino.',
          temperaturaActual: '20°C',
          vientoActual: '16 km/h',
          estadoClima: 'Brisa marina moderada',
          latitud: -13.8833,
          longitud: -76.2667,
          esMock: true,
        ),
      );
    }

    // CASO 2: Mar picado u oleaje en Islas Ballestas (Paracas)
    else if (actividadLimpia.contains('Ballestas')) {
      // 2.1 Alternativa terrestre en Paracas: Reserva Nacional
      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_paracas_tierra_01',
          tituloActividad: 'Reserva Nacional de Paracas (Circuito Terrestre)',
          destino: 'Paracas',
          imagen: 'assets/images/act_reserva1.jpg',
          tipoAlternativa: TipoAlternativa.otraActividadMismoDestino,
          motivoRecomendacion:
              'Ruta panorámica 100% terrestre (Mirador de La Catedral, Playa Roja, Centro de Interpretación) que no depende de la apertura del puerto.',
          condicionesQueJustifican:
              'Vía terrestre habilitada sin riesgo náutico; temperatura de 21°C y vistas marinas espectaculares desde tierra firme.',
          mejorHorarioSugerido: '10:00 AM a 03:00 PM',
          horarioAtencion: HorarioAtencion.paraReservaParacas(),
          descripcionLugar:
              'Circuito por los acantilados de Paracas en transporte turístico terrestre. Permite divisar aves marinas y paisajes costeros sin necesidad de embarcarse en altamar.',
          temperaturaActual: '21°C',
          vientoActual: '18 km/h',
          estadoClima: 'Soleado con brisa',
          latitud: -13.8833,
          longitud: -76.2667,
          esMock: true,
        ),
      );

      // 2.2 Cambio de destino hacia Ica Centro / Viñedos
      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_vinos_ballestas_02',
          tituloActividad: 'Viñedos y bodegas',
          destino: 'Ica',
          imagen: 'assets/images/act_vinos.jpg',
          tipoAlternativa: TipoAlternativa.otroDestinoCercano,
          motivoRecomendacion:
              'Aprovechar la mañana para trasladarse al valle interior de Ica para un almuerzo típico y tour de pisco mientras mejora el mar.',
          condicionesQueJustifican:
              'Clima soleado sin influencia marítima, 25°C constante y cielo despejado.',
          mejorHorarioSugerido: '12:00 PM a 04:30 PM',
          horarioAtencion: HorarioAtencion.paraVinedos(),
          descripcionLugar:
              'Cuna del pisco y la vendimia iqueña. Espacio gastronómico y cultural protegido de la influencia de oleajes marítimos.',
          temperaturaActual: '25°C',
          vientoActual: '10 km/h',
          estadoClima: 'Cálido y agradable',
          latitud: -14.0450,
          longitud: -75.7280,
          esMock: true,
        ),
      );

      // 2.3 Mejor horario para Islas Ballestas (sujeto a capitanía)
      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_ballestas_horario_03',
          tituloActividad: 'Islas Ballestas (Turno Matutino de Mañana)',
          destino: 'Paracas',
          imagen: 'assets/images/act_ballestas1.jpg',
          tipoAlternativa: TipoAlternativa.mismoDestinoOtroHorario,
          motivoRecomendacion:
              'Históricamente, la bahía de Paracas presenta menor oleaje en las primeras horas antes de las brisas térmicas de la tarde.',
          condicionesQueJustifican:
              'Reporte hidrográfico proyecta olas de 1.1 m entre 07:30 AM y 09:30 AM de mañana.',
          mejorHorarioSugerido: 'Primer zarpe de 08:00 AM (Confirmar con Capitanía)',
          horarioAtencion: HorarioAtencion.paraIslasBallestas(),
          descripcionLugar:
              'Excursión marítima en deslizador hacia el santuario de fauna marina con lobos marinos, pingüinos de Humboldt y aves guaneras.',
          temperaturaActual: '18°C',
          vientoActual: '12 km/h',
          estadoClima: 'Brisa marina suave matutina',
          latitud: -13.8333,
          longitud: -76.2500,
          esMock: true,
        ),
      );
    }

    // CASO 3: Radiación UV Extrema en Reserva Nacional de Paracas
    else if (actividadLimpia.contains('Reserva')) {
      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_reserva_uv_01',
          tituloActividad: 'Viñedos y bodegas',
          destino: 'Ica',
          imagen: 'assets/images/act_vinos.jpg',
          tipoAlternativa: TipoAlternativa.otroDestinoCercano,
          motivoRecomendacion:
              'Instalaciones techadas, restaurantes campestres con sombra y bodegas frescas que evitan la exposición solar directa del mediodía.',
          condicionesQueJustifican:
              'Índice UV moderado bajo enramadas y áreas climatizadas, ideal entre las 11:30 y las 15:30 horas.',
          mejorHorarioSugerido: '11:30 AM a 03:30 PM',
          horarioAtencion: HorarioAtencion.paraVinedos(),
          descripcionLugar:
              'Ambiente sombreado y fresco en la campiña para degustar piscos y vinos lejos de la radiación extrema del desierto abierto.',
          temperaturaActual: '24°C',
          vientoActual: '10 km/h',
          estadoClima: 'Sombra y confort térmico',
          latitud: -14.0450,
          longitud: -75.7280,
          esMock: true,
        ),
      );

      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_reserva_horario_02',
          tituloActividad: 'Reserva Nacional de Paracas (Atardecer)',
          destino: 'Paracas',
          imagen: 'assets/images/act_reserva1.jpg',
          tipoAlternativa: TipoAlternativa.mismoDestinoOtroHorario,
          motivoRecomendacion:
              'Al caer la tarde el índice UV desciende drásticamente a niveles seguros y la puesta de sol en Playa Supay y Yumaque es excepcional.',
          condicionesQueJustifican:
              'Índice UV inferior a 3 después de las 16:00 horas, con brisa fresca costera.',
          mejorHorarioSugerido: '04:00 PM a 06:15 PM',
          horarioAtencion: HorarioAtencion.paraReservaParacas(),
          descripcionLugar:
              'Horario dorado ideal para fotografía paisajística sin peligro de quemaduras solares.',
          temperaturaActual: '19°C',
          vientoActual: '15 km/h',
          estadoClima: 'Poco viento y cielo despejado',
          latitud: -13.8833,
          longitud: -76.2667,
          esMock: true,
        ),
      );
    }

    // CASO GENERAL / FALLBACK
    else {
      alternativas.add(
        AlternativaRecomendada(
          id: 'alt_rec_general_01',
          tituloActividad: 'Viñedos y bodegas',
          destino: 'Ica',
          imagen: 'assets/images/act_vinos.jpg',
          tipoAlternativa: TipoAlternativa.otraActividadMismoDestino,
          motivoRecomendacion:
              'Actividad turística de gran estabilidad climatológica durante todo el año en la provincia de Ica.',
          condicionesQueJustifican:
              'Zonas de sombra, degustación guiada y gastronomía típica.',
          mejorHorarioSugerido: '11:00 AM a 04:00 PM',
          horarioAtencion: HorarioAtencion.paraVinedos(),
          descripcionLugar:
              'Tradición pisquera y gastronomía iqueña en haciendas coloniales.',
          temperaturaActual: '24°C',
          vientoActual: '11 km/h',
          estadoClima: 'Favorable',
          latitud: -14.0450,
          longitud: -75.7280,
          esMock: true,
        ),
      );
    }

    return alternativas;
  }

  /// Retorna una lista general de alternativas destacadas para la sección de alertas
  List<AlternativaRecomendada> obtenerAlternativasGenerales() {
    return [
      AlternativaRecomendada(
        id: 'alt_gen_01',
        tituloActividad: 'Viñedos y bodegas',
        destino: 'Ica (Campiña)',
        imagen: 'assets/images/act_vinos.jpg',
        tipoAlternativa: TipoAlternativa.otraActividadMismoDestino,
        motivoRecomendacion:
            'Excelente alternativa ante vientos fuertes o marejadas en la costa. Actividades en bodegas techadas.',
        condicionesQueJustifican: 'Clima templado de 24°C sin influencia del viento Paracas.',
        mejorHorarioSugerido: '11:30 AM a 04:30 PM',
        horarioAtencion: HorarioAtencion.paraVinedos(),
        descripcionLugar:
            'Tours enológicos, degustación de pisco iqueño y restaurante criollo.',
        temperaturaActual: '24°C',
        vientoActual: '11 km/h',
        estadoClima: 'Óptimo',
        latitud: -14.0450,
        longitud: -75.7280,
        esMock: true,
      ),
      AlternativaRecomendada(
        id: 'alt_gen_02',
        tituloActividad: 'Reserva Nacional de Paracas',
        destino: 'Paracas',
        imagen: 'assets/images/act_reserva1.jpg',
        tipoAlternativa: TipoAlternativa.otroDestinoCercano,
        motivoRecomendacion:
            'Circuito vehicular transitable si el muelle de lanchas a Ballestas permanece cerrado.',
        condicionesQueJustifican: 'Vías habilitadas, cielo despejado y brisa marina moderada.',
        mejorHorarioSugerido: '09:00 AM a 03:00 PM',
        horarioAtencion: HorarioAtencion.paraReservaParacas(),
        descripcionLugar:
            'Miradores de La Catedral, Playa Roja y Centro de Interpretación.',
        temperaturaActual: '20°C',
        vientoActual: '16 km/h',
        estadoClima: 'Favorable',
        latitud: -13.8833,
        longitud: -76.2667,
        esMock: true,
      ),
      AlternativaRecomendada(
        id: 'alt_gen_03',
        tituloActividad: 'Sandboarding matutino en Huacachina',
        destino: 'Huacachina',
        imagen: 'assets/images/detalle_sandboarding_1.jpg',
        tipoAlternativa: TipoAlternativa.mismoDestinoOtroHorario,
        motivoRecomendacion:
            'Mejor ventana horaria para deslizarse en dunas antes del inicio de las corrientes de la tarde.',
        condicionesQueJustifican: 'Viento suave de 8 a 12 km/h y visibilidad del 100%.',
        mejorHorarioSugerido: '08:00 AM a 10:30 AM',
        horarioAtencion: HorarioAtencion.paraHuacachina(),
        descripcionLugar:
            'Descensos en tabla sobre arena suave en las dunas del oasis.',
        temperaturaActual: '19°C',
        vientoActual: '9 km/h',
        estadoClima: 'Calmo',
        latitud: -14.0875,
        longitud: -75.7628,
        esMock: true,
      ),
    ];
  }
}
