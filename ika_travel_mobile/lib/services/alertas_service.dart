import 'package:flutter/material.dart';

import '../models/alerta_modelo.dart';
import 'weather_service.dart'; // 👈 NUEVO: Para obtener alertas del backend

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

  // 👇 MODIFICADO: Ahora carga las alertas desde el backend
  AlertasService._interno() {
    cargarAlertasDesdeBackend();
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

  // 👇 NUEVO: Cargar alertas desde el backend
  Future<void> cargarAlertasDesdeBackend() async {
    final weather = WeatherService();
    final datos = await weather.obtenerAlertasClimaticas();

    if (datos != null && datos.isNotEmpty) {
      // Convertimos los datos del backend al modelo AlertaClima
      final List<AlertaClima> alertasReales = datos.map((item) {
        // Determinamos el nivel de riesgo según el backend
        NivelRiesgo nivel = NivelRiesgo.informativo;
        final nivelStr = (item['nivel_riesgo'] ?? '').toString().toLowerCase();
        if (nivelStr.contains('crítico') || nivelStr.contains('critico')) {
          nivel = NivelRiesgo.critico;
        } else if (nivelStr.contains('alto')) {
          nivel = NivelRiesgo.alto;
        } else if (nivelStr.contains('precaución') ||
            nivelStr.contains('precaucion')) {
          nivel = NivelRiesgo.precaucion;
        }

        return AlertaClima(
          id:
              item['id']?.toString() ??
              'real_${DateTime.now().millisecondsSinceEpoch}',
          titulo: item['titulo'] ?? 'Alerta climática',
          destino: item['destino'] ?? 'Ica',
          actividad: item['actividad'] ?? 'General',
          fechaHora: item['fecha_hora'] != null
              ? DateTime.parse(item['fecha_hora'].toString())
              : DateTime.now(),
          nivelRiesgo: nivel,
          motivoCambio:
              item['motivo'] ?? 'Cambio en las condiciones climáticas',
          impactoActividad:
              item['impacto'] ?? 'Consultar con operadores locales',
          condicionAnterior: CondicionClima(
            fechaHora: DateTime.now().subtract(const Duration(hours: 3)),
            estadoCielo: 'Anterior',
            temperatura: '--',
            velocidadViento: '--',
            probabilidadLluvia: '--',
            indiceUv: '--',
          ),
          condicionActual: CondicionClima(
            fechaHora: DateTime.now(),
            estadoCielo: 'Actual',
            temperatura: '--',
            velocidadViento: '--',
            probabilidadLluvia: '--',
            indiceUv: '--',
          ),
          recomendacionesSeguridad: List<String>.from(
            item['recomendaciones'] ?? [],
          ),
          esMock: false, // 👈 Ya no son mock, vienen del backend
          activa: true,
        );
      }).toList();

      alertasNotifier.value = alertasReales;
    } else {
      // Si el backend no tiene alertas (devuelve []), mostramos lista vacía
      alertasNotifier.value = [];
      print('ℹ️ No hay alertas climáticas activas en el backend.');
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
      final sigueActividad = actividades.any(
        (act) =>
            act.replaceAll('\n', ' ') == alerta.actividad.replaceAll('\n', ' '),
      );

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
      motivoCambio: 'Detección automática: Incremento de viento de 15 km/h a 38 km/h en los últimos 20 minutos (Umbral > 25 km/h superado).',
      impactoActividad: 'Pérdida de tracción en dunas altas y arena en suspensión. Se sugiere operar solo en circuitos bajos o reprogramar paseo.',
      condicionAnterior: CondicionClima(
        fechaHora: DateTime.now().subtract(const Duration(minutes: 25)),
        estadoCielo: 'Soleado despejado',
        temperatura: '25°C',
        velocidadViento: '15 km/h',
        probabilidadLluvia: '0%',
        indiceUv: 'Muy Alto (8)',
        metricasDetalladas: const [
          MetricaClima(
            nombre: 'Viento',
            valor: '15',
            unidad: 'km/h',
            icono: Icons.air,
          ),
          MetricaClima(
            nombre: 'Temperatura',
            valor: '25',
            unidad: '°C',
            icono: Icons.thermostat,
          ),
          MetricaClima(
            nombre: 'Visibilidad',
            valor: '10',
            unidad: 'km',
            icono: Icons.visibility,
          ),
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
          MetricaClima(
            nombre: 'Viento',
            valor: '38',
            unidad: 'km/h',
            icono: Icons.air,
          ),
          MetricaClima(
            nombre: 'Temperatura',
            valor: '28',
            unidad: '°C',
            icono: Icons.thermostat,
          ),
          MetricaClima(
            nombre: 'Visibilidad',
            valor: '30',
            unidad: 'm',
            icono: Icons.visibility_off,
          ),
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
