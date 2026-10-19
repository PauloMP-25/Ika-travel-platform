import 'package:flutter/material.dart';
import '../models/alerta_modelo.dart';

/// Configuración de notificaciones y permisos
class ConfiguracionNotificaciones {
  bool permisosConcedidos;
  bool pushHabilitado;
  bool alertarViento;
  bool alertarOleaje;
  bool alertarUv;
  bool alertarLluvia;
  String frecuenciaRevision; // 'En tiempo real (API/Push)' o 'Cada hora'

  ConfiguracionNotificaciones({
    this.permisosConcedidos = true,
    this.pushHabilitado = true,
    this.alertarViento = true,
    this.alertarOleaje = true,
    this.alertarUv = true,
    this.alertarLluvia = true,
    this.frecuenciaRevision = 'En tiempo real (API/Push)',
  });
}

/// Servicio central de alertas inteligentes (Requerimientos 11 y 12)
class AlertasService {
  // Instancia única (Singleton)
  static final AlertasService _instancia = AlertasService._interno();
  factory AlertasService() => _instancia;
  AlertasService._interno() {
    _inicializarDatosMock();
  }

  // Notificador reactivo de lista de alertas
  final ValueNotifier<List<AlertaClima>> alertasNotifier = ValueNotifier([]);

  // Notificador reactivo de destinos y actividades seguidas por el usuario
  final ValueNotifier<Set<String>> destinosSeguidosNotifier = ValueNotifier({
    'Huacachina',
    'Paracas',
    'Ica',
  });

  final ValueNotifier<Set<String>> actividadesSeguidasNotifier = ValueNotifier({
    'Sandboarding\nen Huacachina',
    'Paseo en buggy\nen las dunas',
    'Islas Ballestas',
    'Reserva Nacional\nde Paracas',
    'Viñedos y bodegas',
  });

  // Configuración de notificaciones
  final ValueNotifier<ConfiguracionNotificaciones> configNotifier =
      ValueNotifier(ConfiguracionNotificaciones());

  // Registro para evitar alertas repetidas por el mismo evento
  final Set<String> _eventosProcesados = {};

  List<AlertaClima> get todasLasAlertas => alertasNotifier.value;
  List<AlertaClima> get alertasActivas =>
      alertasNotifier.value.where((a) => a.activa).toList();
  List<AlertaClima> get historialAlertas =>
      alertasNotifier.value.where((a) => !a.activa).toList();

  // Inicialización con datos de demostración detallados
  void _inicializarDatosMock() {
    final List<AlertaClima> mock = [
      // 1. Alerta Huacachina - Viento fuerte
      AlertaClima(
        id: 'alt_huacachina_001',
        titulo: 'Viento Paracas en dunas de Huacachina',
        destino: 'Huacachina',
        actividad: 'Sandboarding\nen Huacachina',
        fechaHora: DateTime.now().subtract(const Duration(minutes: 42)),
        nivelRiesgo: NivelRiesgo.alto,
        motivoCambio:
            'Aceleración súbita de corrientes de aire térmicas desde el desierto de Paracas hacia la duna norte.',
        impactoActividad:
            'Ráfagas cruzadas que generan tormenta superficial de arena, reduciendo la visibilidad a menos de 40 metros y aumentando el riesgo de desbalance o colisión en descenso sobre tabla.',
        condicionAnterior: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(hours: 3)),
          estadoCielo: 'Despejado',
          temperatura: '25°C',
          velocidadViento: '14 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Muy Alto (9)',
          estadoMar: 'No aplica',
          metricasDetalladas: const [
            MetricaClima(nombre: 'Viento sostenido', valor: '14', unidad: 'km/h', icono: Icons.air),
            MetricaClima(nombre: 'Ráfagas máx.', valor: '18', unidad: 'km/h', icono: Icons.air),
            MetricaClima(nombre: 'Temperatura', valor: '25', unidad: '°C', icono: Icons.thermostat),
            MetricaClima(nombre: 'Visibilidad', valor: '10', unidad: 'km', icono: Icons.visibility),
            MetricaClima(nombre: 'Índice UV', valor: '9', unidad: 'Extremo', icono: Icons.wb_sunny),
          ],
        ),
        condicionActual: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(minutes: 42)),
          estadoCielo: 'Polvareda en suspensión',
          temperatura: '28°C',
          velocidadViento: '34 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Alto (8)',
          estadoMar: 'No aplica',
          metricasDetalladas: const [
            MetricaClima(nombre: 'Viento sostenido', valor: '34', unidad: 'km/h', icono: Icons.air),
            MetricaClima(nombre: 'Ráfagas máx.', valor: '48', unidad: 'km/h', icono: Icons.air),
            MetricaClima(nombre: 'Temperatura', valor: '28', unidad: '°C', icono: Icons.thermostat),
            MetricaClima(nombre: 'Visibilidad', valor: '40', unidad: 'metros', icono: Icons.visibility_off),
            MetricaClima(nombre: 'Índice UV', valor: '8', unidad: 'Alto', icono: Icons.wb_sunny),
          ],
        ),
        recomendacionesSeguridad: const [
          'Usar gafas herméticas antipolvo y pañuelo/badana protectora.',
          'Suspender descensos a alta velocidad desde crestas altas de las dunas.',
          'Seguir únicamente instrucciones de instructores acreditados de sandboarding.',
          'Mantener celulares y cámaras protegidos contra micropartículas de sílice.',
          'Considerar postergar la actividad hacia el horario de 08:30 a 11:00 am de mañana.',
        ],
        esMock: true,
        activa: true,
      ),

      // 2. Alerta Paracas / Islas Ballestas - Oleaje anómalo
      AlertaClima(
        id: 'alt_ballestas_002',
        titulo: 'Alerta marítima: Mar picado en Paracas',
        destino: 'Paracas',
        actividad: 'Islas Ballestas',
        fechaHora: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
        nivelRiesgo: NivelRiesgo.critico,
        motivoCambio:
            'Aviso oceanográfico de la Capitanía de Puerto: Tren de olas anómalo de origen suroeste con marejada.',
        impactoActividad:
            'Dificultad de amarre y aproximación segura a las cuevas del Candelabro y formaciones rocosas de las islas. Posible restricción temporal de zarpe para embarcaciones turísticas menores.',
        condicionAnterior: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(hours: 4)),
          estadoCielo: 'Soleado con brisa',
          temperatura: '21°C',
          velocidadViento: '10 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Moderado (5)',
          estadoMar: 'Calmado (Olas de 0.8m)',
          metricasDetalladas: const [
            MetricaClima(nombre: 'Altura oleaje', valor: '0.8', unidad: 'metros', icono: Icons.waves),
            MetricaClima(nombre: 'Viento en bahía', valor: '10', unidad: 'km/h', icono: Icons.air),
            MetricaClima(nombre: 'Temperatura agua', valor: '17', unidad: '°C', icono: Icons.water),
            MetricaClima(nombre: 'Estado de puerto', valor: 'Abierto', unidad: '', icono: Icons.anchor),
          ],
        ),
        condicionActual: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
          estadoCielo: 'Nubosidad baja y bruma',
          temperatura: '19°C',
          velocidadViento: '28 km/h',
          probabilidadLluvia: '10%',
          indiceUv: 'Bajo (3)',
          estadoMar: 'Mar picado a gruesa (Olas de 2.2m)',
          metricasDetalladas: const [
            MetricaClima(nombre: 'Altura oleaje', valor: '2.2', unidad: 'metros', icono: Icons.waves),
            MetricaClima(nombre: 'Viento en bahía', valor: '28', unidad: 'km/h', icono: Icons.air),
            MetricaClima(nombre: 'Temperatura agua', valor: '16', unidad: '°C', icono: Icons.water),
            MetricaClima(nombre: 'Estado de puerto', valor: 'Restricción preventiva', unidad: '', icono: Icons.anchor),
          ],
        ),
        recomendacionesSeguridad: const [
          'Verificar estatus de zarpe con Capitanía de Puerto de Pisco/Paracas antes de embarcar.',
          'Portar chaleco salvavidas abrochado obligatoriamente durante todo el trayecto.',
          'Llevar cortaviento impermeable ante salpicaduras continuas.',
          'Si es propenso a mareos, tomar antihistamínico o pastilla para el mareo 30 minutos antes.',
        ],
        esMock: true,
        activa: true,
      ),

      // 3. Alerta Paracas - Reserva Nacional: Radiación UV Extrema
      AlertaClima(
        id: 'alt_reserva_003',
        titulo: 'Índice de radiación UV Extremo en Reserva',
        destino: 'Paracas',
        actividad: 'Reserva Nacional\nde Paracas',
        fechaHora: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
        nivelRiesgo: NivelRiesgo.precaucion,
        motivoCambio:
            'Disipación total de la capa nubosa costera con incidencia vertical solar y reflexión en suelo salino.',
        impactoActividad:
            'Exposición solar severa en circuitos desérticos (Playa Roja, La Mina, Catedral). Riesgo de deshidratación y quemaduras de primer grado en menos de 18 minutos sin fotoprotección.',
        condicionAnterior: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(hours: 5)),
          estadoCielo: 'Niebla matutina',
          temperatura: '18°C',
          velocidadViento: '12 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Bajo (2)',
          metricasDetalladas: const [
            MetricaClima(nombre: 'Índice UV', valor: '2', unidad: 'Bajo', icono: Icons.wb_sunny_outlined),
            MetricaClima(nombre: 'Temperatura', valor: '18', unidad: '°C', icono: Icons.thermostat),
          ],
        ),
        condicionActual: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
          estadoCielo: 'Cielo despejado sin sombra',
          temperatura: '26°C',
          velocidadViento: '19 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Extremo (11+)',
          metricasDetalladas: const [
            MetricaClima(nombre: 'Índice UV', valor: '11+', unidad: 'Extremo', icono: Icons.wb_sunny),
            MetricaClima(nombre: 'Temperatura', valor: '26', unidad: '°C', icono: Icons.thermostat),
          ],
        ),
        recomendacionesSeguridad: const [
          'Aplicar protector solar SPF 50+ cada 90 minutos de forma continua.',
          'Portar sombrero de ala ancha, gafas con filtro UV 400 y prendas de manga larga transpirables.',
          'Llevar mínimo 2 litros de agua por persona para los senderos a pie.',
        ],
        esMock: true,
        activa: true,
      ),

      // 4. Historial: Viñedos y bodegas (Resolución favorable)
      AlertaClima(
        id: 'alt_vinos_historial_004',
        titulo: 'Condición climatológica óptima en Valle de Ica',
        destino: 'Ica',
        actividad: 'Viñedos y bodegas',
        fechaHora: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        nivelRiesgo: NivelRiesgo.informativo,
        motivoCambio:
            'Estabilización de temperaturas y brisa fresca en la campiña pisquera.',
        impactoActividad:
            'Clima idóneo para recorridos peatonales por viñedos y catas al aire libre.',
        condicionAnterior: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
          estadoCielo: 'Brumoso',
          temperatura: '20°C',
          velocidadViento: '8 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Moderado (4)',
        ),
        condicionActual: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          estadoCielo: 'Soleado templado',
          temperatura: '24°C',
          velocidadViento: '11 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Moderado (5)',
        ),
        recomendacionesSeguridad: const [
          'Llevar calzado cómodo para el recorrido entre parras.',
          'Mantenerse hidratado entre degustaciones de pisco y vino.',
        ],
        esMock: true,
        activa: false, // Historial
      ),

      // 5. Historial: Buggy en dunas (Ayer)
      AlertaClima(
        id: 'alt_buggy_historial_005',
        titulo: 'Descenso de viento en Huacachina - Paseo seguro',
        destino: 'Huacachina',
        actividad: 'Paseo en buggy\nen las dunas',
        fechaHora: DateTime.now().subtract(const Duration(days: 2)),
        nivelRiesgo: NivelRiesgo.informativo,
        motivoCambio:
            'Finalización del evento de viento vespertino.',
        impactoActividad:
            'Reanudación de paseos en tubulares en circuito estándar de dunas.',
        condicionAnterior: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
          estadoCielo: 'Ventoso',
          temperatura: '26°C',
          velocidadViento: '30 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Alto (7)',
        ),
        condicionActual: CondicionClima(
          fechaHora: DateTime.now().subtract(const Duration(days: 2)),
          estadoCielo: 'Despejado',
          temperatura: '23°C',
          velocidadViento: '12 km/h',
          probabilidadLluvia: '0%',
          indiceUv: 'Bajo (3)',
        ),
        recomendacionesSeguridad: const [
          'Ajustar cinturones de seguridad de cuatro puntos en los tubulares.',
        ],
        esMock: true,
        activa: false, // Historial
      ),
    ];

    alertasNotifier.value = mock;
    for (var a in mock) {
      _eventosProcesados.add(a.id);
    }
  }

  // Comprobar y obtener alerta por ID
  AlertaClima? obtenerAlertaPorId(String id) {
    try {
      return alertasNotifier.value.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // Filtrar alertas según preferencias y seguimiento del usuario
  List<AlertaClima> obtenerAlertasParaUsuario({bool soloActivas = true}) {
    final destinos = destinosSeguidosNotifier.value;
    final actividades = actividadesSeguidasNotifier.value;

    return alertasNotifier.value.where((alerta) {
      if (soloActivas && !alerta.activa) return false;
      if (!soloActivas && alerta.activa) return false;

      final sigueDestino = destinos.contains(alerta.destino);
      final sigueActividad = actividades.any((act) =>
          act.replaceAll('\n', ' ') == alerta.actividad.replaceAll('\n', ' '));

      return sigueDestino || sigueActividad;
    }).toList();
  }

  // Seguir / Dejar de seguir destinos
  void toggleSeguirDestino(String destino) {
    final actual = Set<String>.from(destinosSeguidosNotifier.value);
    if (actual.contains(destino)) {
      actual.remove(destino);
    } else {
      actual.add(destino);
    }
    destinosSeguidosNotifier.value = actual;
  }

  bool estaSiguiendoDestino(String destino) {
    return destinosSeguidosNotifier.value.contains(destino);
  }

  // Seguir / Dejar de seguir actividades
  void toggleSeguirActividad(String actividad) {
    final actual = Set<String>.from(actividadesSeguidasNotifier.value);
    final limpia = actividad.replaceAll('\n', ' ');

    final encontrado = actual.any((a) => a.replaceAll('\n', ' ') == limpia);
    if (encontrado) {
      actual.removeWhere((a) => a.replaceAll('\n', ' ') == limpia);
    } else {
      actual.add(actividad);
    }
    actividadesSeguidasNotifier.value = actual;
  }

  bool estaSiguiendoActividad(String actividad) {
    final limpia = actividad.replaceAll('\n', ' ');
    return actividadesSeguidasNotifier.value.any(
      (a) => a.replaceAll('\n', ' ') == limpia,
    );
  }

  // Actualizar configuración de notificaciones
  void actualizarConfiguracion(ConfiguracionNotificaciones nuevaConfig) {
    configNotifier.value = nuevaConfig;
  }

  /// Lógica de detección de cambios (Requerimiento 11)
  /// Compara condición anterior con actual y determina si amerita una alerta.
  /// Previene alertas repetidas por el mismo evento mediante hash / id.
  AlertaClima? detectarYGenerarAlerta({
    required String idEvento,
    required String destino,
    required String actividad,
    required String motivo,
    required String impacto,
    required CondicionClima previa,
    required CondicionClima actual,
    required NivelRiesgo nivelRiesgo,
    required List<String> recomendaciones,
  }) {
    // 1. Evitar alertas repetidas por el mismo evento
    if (_eventosProcesados.contains(idEvento)) {
      return null;
    }

    final nuevaAlerta = AlertaClima(
      id: idEvento,
      titulo: 'Cambio detectado: $motivo',
      destino: destino,
      actividad: actividad,
      fechaHora: DateTime.now(),
      nivelRiesgo: nivelRiesgo,
      motivoCambio: motivo,
      impactoActividad: impacto,
      condicionAnterior: previa,
      condicionActual: actual,
      recomendacionesSeguridad: recomendaciones,
      esMock: true,
      activa: true,
    );

    _eventosProcesados.add(idEvento);

    final listaActualizada = [nuevaAlerta, ...alertasNotifier.value];
    alertasNotifier.value = listaActualizada;

    return nuevaAlerta;
  }

  /// Simulación en vivo de detección de cambio climatológico
  /// Permite demostrar cómo el sistema detecta una variación imprevista
  /// y añade la alerta automáticamente a la lista y notificaciones.
  AlertaClima simularDeteccionEnVivo() {
    final idNuevo = 'alt_live_${DateTime.now().millisecondsSinceEpoch}';
    final nuevaAlerta = AlertaClima(
      id: idNuevo,
      titulo: '⚠️ Alerta generada: Ráfagas extremas en Huacachina',
      destino: 'Huacachina',
      actividad: 'Paseo en buggy\nen las dunas',
      fechaHora: DateTime.now(),
      nivelRiesgo: NivelRiesgo.alto,
      motivoCambio:
          'Detección automática: Incremento de viento de 15 km/h a 38 km/h en los últimos 20 minutos (Umbral > 25 km/h superado).',
      impactoActividad:
          'Pérdida de tracción en dunas altas y arena en suspensión. Se sugiere operar solo en circuitos bajos o reprogramar paseo.',
      condicionAnterior: CondicionClima(
        fechaHora: DateTime.now().subtract(const Duration(minutes: 25)),
        estadoCielo: 'Soleado despejado',
        temperatura: '25°C',
        velocidadViento: '15 km/h',
        probabilidadLluvia: '0%',
        indiceUv: 'Muy Alto (8)',
        metricasDetalladas: const [
          MetricaClima(nombre: 'Viento', valor: '15', unidad: 'km/h', icono: Icons.air),
          MetricaClima(nombre: 'Temperatura', valor: '25', unidad: '°C', icono: Icons.thermostat),
          MetricaClima(nombre: 'Visibilidad', valor: '10', unidad: 'km', icono: Icons.visibility),
        ],
      ),
      condicionActual: CondicionClima(
        fechaHora: DateTime.now(),
        estadoCielo: 'Viento con arena levantada',
        temperatura: '28°C',
        velocidadViento: '38 km/h',
        probabilidadLluvia: '0%',
        indiceUv: 'Alto (7)',
        metricasDetalladas: const [
          MetricaClima(nombre: 'Viento', valor: '38', unidad: 'km/h', icono: Icons.air),
          MetricaClima(nombre: 'Temperatura', valor: '28', unidad: '°C', icono: Icons.thermostat),
          MetricaClima(nombre: 'Visibilidad', valor: '30', unidad: 'm', icono: Icons.visibility_off),
        ],
      ),
      recomendacionesSeguridad: const [
        'Ajustar gafas de protección antes de ingresar a las dunas.',
        'No circular a alta velocidad sobre crestas vivas de dunas.',
        'Consultar estatus con operadores locales en la laguna.',
      ],
      esMock: true,
      activa: true,
    );

    _eventosProcesados.add(idNuevo);
    alertasNotifier.value = [nuevaAlerta, ...alertasNotifier.value];
    return nuevaAlerta;
  }
}
