import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/alerta_modelo.dart';

class ConfiguracionNotificaciones {
  bool permisosConcedidos;
  bool pushHabilitado;
  bool alertarViento;
  bool alertarOleaje;
  bool alertarUv;
  bool alertarLluvia;
  String frecuenciaRevision;

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

/// Servicio central de alertas inteligentes.
///
/// Estrategia 100% real:
/// - Alertas activas: `GET /api/v1/weather/alerts`.
/// - Historial: `GET /api/v1/weather/alerts/history`.
/// - Marcar como leída: `PATCH /api/v1/weather/alerts/{id}`.
/// - Alternativas/recomendaciones: `GET /api/v1/weather/recommendations`.
/// - Se refresca automáticamente cada 5 minutos.
class AlertasService {
  static final AlertasService _instancia = AlertasService._interno();
  factory AlertasService() => _instancia;

  AlertasService._interno() {
    _iniciarRefrescoAutomatico();
  }

  final ValueNotifier<List<AlertaClima>> alertasNotifier = ValueNotifier([]);
  final ValueNotifier<List<AlertaClima>> historialNotifier = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> recomendacionesNotifier =
      ValueNotifier([]);

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

  final ValueNotifier<ConfiguracionNotificaciones> configNotifier =
      ValueNotifier(ConfiguracionNotificaciones());

  Timer? _refrescoTimer;
  bool _cargandoDesdeBackend = false;
  bool _marcando = false;
  DateTime? _ultimaActualizacion;
  String? _ultimoError;

  List<AlertaClima> get todasLasAlertas => alertasNotifier.value;
  List<AlertaClima> get alertasActivas => alertasNotifier.value;
  List<AlertaClima> get historialAlertas => historialNotifier.value;
  List<Map<String, dynamic>> get recomendaciones =>
      recomendacionesNotifier.value;

  DateTime? get ultimaActualizacion => _ultimaActualizacion;
  String? get ultimoError => _ultimoError;
  bool get cargando => _cargandoDesdeBackend;
  bool get marcando => _marcando;
  bool get conectadoAlBackend =>
      _ultimaActualizacion != null && _ultimoError == null;

  // ---------------------------------------------------------------
  // Refresco automático
  // ---------------------------------------------------------------

  void _iniciarRefrescoAutomatico() {
    Future.microtask(() async {
      await cargarDesdeBackend();
      await cargarHistorial();
      await cargarRecomendaciones();
    });
    _refrescoTimer?.cancel();
    _refrescoTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await cargarDesdeBackend();
      await cargarHistorial();
      await cargarRecomendaciones();
    });
  }

  // ---------------------------------------------------------------
  // Alertas activas
  // ---------------------------------------------------------------

  Future<void> cargarDesdeBackend() async {
    if (_cargandoDesdeBackend) return;
    _cargandoDesdeBackend = true;

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.weatherAlerts),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _ultimoError = 'HTTP ${response.statusCode}';
        debugPrint('[AlertasService] Backend respondió ${response.statusCode}');
        return;
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) {
        _ultimoError = 'Formato de respuesta inválido';
        return;
      }

      final alertasBackend = decoded
          .whereType<Map<String, dynamic>>()
          .map(_alertaDesdeBackend)
          .whereType<AlertaClima>()
          .toList();

      alertasNotifier.value = alertasBackend;
      _ultimoError = null;
      _ultimaActualizacion = DateTime.now();

      debugPrint(
        '[AlertasService] ${alertasBackend.length} alertas activas cargadas',
      );
    } on TimeoutException {
      _ultimoError = 'Timeout al consultar alertas';
      debugPrint('[AlertasService] Timeout');
    } catch (e) {
      _ultimoError = e.toString();
      debugPrint('[AlertasService] Error al cargar alertas: $e');
    } finally {
      _cargandoDesdeBackend = false;
    }
  }

  // ---------------------------------------------------------------
  // Historial
  // ---------------------------------------------------------------

  Future<void> cargarHistorial() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.weatherAlertsHistory),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          '[AlertasService] Historial respondió ${response.statusCode}',
        );
        return;
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) return;

      final alertas = decoded
          .whereType<Map<String, dynamic>>()
          .map(_alertaDesdeBackend)
          .whereType<AlertaClima>()
          .toList();

      historialNotifier.value = alertas;
      debugPrint('[AlertasService] ${alertas.length} alertas en historial');
    } catch (e) {
      debugPrint('[AlertasService] Error al cargar historial: $e');
    }
  }

  // ---------------------------------------------------------------
  // Marcar como leída
  // ---------------------------------------------------------------

  Future<bool> marcarComoLeida(String alertaId) async {
    if (_marcando) return false;
    _marcando = true;
    try {
      final response = await http
          .patch(
            Uri.parse(ApiConfig.weatherAlertById(alertaId)),
            headers: {
              ...ApiConfig.defaultHeaders,
              'Content-Type': 'application/json',
            },
            body: json.encode({'read': true}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          '[AlertasService] Error al marcar como leída: ${response.statusCode}',
        );
        return false;
      }

      await cargarDesdeBackend();
      await cargarHistorial();
      return true;
    } catch (e) {
      debugPrint('[AlertasService] Error al marcar como leída: $e');
      return false;
    } finally {
      _marcando = false;
    }
  }

  // ---------------------------------------------------------------
  // Recomendaciones (alternativas) desde el backend
  // ---------------------------------------------------------------

  Future<void> cargarRecomendaciones() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.recommendations),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint(
          '[AlertasService] Recomendaciones respondió ${response.statusCode}',
        );
        return;
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) return;

      recomendacionesNotifier.value = decoded
          .whereType<Map<String, dynamic>>()
          .toList();

      debugPrint(
        '[AlertasService] ${recomendacionesNotifier.value.length} recomendaciones cargadas',
      );
    } catch (e) {
      debugPrint('[AlertasService] Error al cargar recomendaciones: $e');
    }
  }

  // ---------------------------------------------------------------
  // Parseo del JSON del backend
  // ---------------------------------------------------------------

  AlertaClima? _alertaDesdeBackend(Map<String, dynamic> json) {
    try {
      final id = (json['id'] ?? '').toString();
      if (id.isEmpty) return null;

      final code = (json['code'] ?? '').toString();
      final severity = (json['severity'] ?? 'low').toString();
      final zone = (json['zone'] ?? 'Ica').toString();
      final message = (json['message'] ?? '').toString();
      final read = json['read'] == true;

      final nivelRiesgo = _nivelDesdeSeveridad(severity);
      final (titulo, actividad) = _traducirCodigoAlerta(code);

      final inicio =
          DateTime.tryParse((json['starts_at'] ?? '').toString())?.toLocal() ??
          DateTime.now();

      final condicionPlaceholder = CondicionClima(
        fechaHora: inicio,
        estadoCielo: '--',
        temperatura: '--',
        velocidadViento: '--',
        probabilidadLluvia: '--',
        indiceUv: '--',
        estadoMar: 'No aplica',
      );

      return AlertaClima(
        id: id,
        titulo: titulo,
        destino: zone,
        actividad: actividad,
        fechaHora: inicio,
        nivelRiesgo: nivelRiesgo,
        motivoCambio: message,
        impactoActividad: '',
        condicionAnterior: condicionPlaceholder,
        condicionActual: condicionPlaceholder,
        recomendacionesSeguridad: _recomendacionesPorCodigo(code),
        esMock: false,
        activa: !read,
      );
    } catch (e) {
      debugPrint('[AlertasService] Error al parsear alerta: $e');
      return null;
    }
  }

  NivelRiesgo _nivelDesdeSeveridad(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'extreme':
      case 'critical':
        return NivelRiesgo.critico;
      case 'medium':
        return NivelRiesgo.alto;
      case 'low':
        return NivelRiesgo.precaucion;
      default:
        return NivelRiesgo.informativo;
    }
  }

  (String, String) _traducirCodigoAlerta(String code) {
    switch (code) {
      case 'extreme_uv':
        return ('Radiación UV extrema', 'Actividades al aire libre');
      case 'strong_wind':
        return ('Vientos fuertes', 'Paseo en buggy\nen las dunas');
      case 'heavy_rain':
        return ('Lluvia intensa', 'Actividades al aire libre');
      case 'high_waves':
        return ('Oleaje alto', 'Islas Ballestas');
      case 'heat_wave':
        return ('Ola de calor', 'Actividades al aire libre');
      default:
        return ('Alerta climática', 'Actividades turísticas');
    }
  }

  List<String> _recomendacionesPorCodigo(String code) {
    switch (code) {
      case 'extreme_uv':
        return [
          'Usar protector solar SPF 50+ y reaplicar cada 2 horas.',
          'Llevar sombrero de ala ancha y gafas con filtro UV.',
          'Evitar exposición directa entre las 11:00 y las 14:00.',
        ];
      case 'strong_wind':
        return [
          'Asegurar objetos personales y usar gafas antipolvo.',
          'Suspender actividades de altura (sandboarding, parapente).',
          'Consultar con operadores locales antes de salir.',
        ];
      case 'heavy_rain':
        return [
          'Evitar zonas inundables y cauces secos.',
          'Llevar ropa impermeable y calzado antideslizante.',
          'Postergar actividades al aire libre.',
        ];
      case 'high_waves':
        return [
          'Verificar estatus de zarpe con la Capitanía de Puerto.',
          'Usar chaleco salvavidas durante todo el trayecto.',
          'Personas propensas a mareos: tomar medicación previa.',
        ];
      default:
        return [
          'Consultar con operadores locales.',
          'Mantenerse informado del pronóstico.',
        ];
    }
  }

  // ---------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------

  AlertaClima? obtenerAlertaPorId(String id) {
    try {
      return alertasNotifier.value.firstWhere((a) => a.id == id);
    } catch (_) {
      try {
        return historialNotifier.value.firstWhere((a) => a.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  List<AlertaClima> obtenerAlertasParaUsuario({bool soloActivas = true}) {
    final destinos = destinosSeguidosNotifier.value;
    final actividades = actividadesSeguidasNotifier.value;
    final fuente = soloActivas
        ? alertasNotifier.value
        : historialNotifier.value;

    return fuente.where((alerta) {
      final sigueDestino = destinos.contains(alerta.destino);
      final sigueActividad = actividades.any(
        (act) =>
            act.replaceAll('\n', ' ') == alerta.actividad.replaceAll('\n', ' '),
      );
      return sigueDestino || sigueActividad;
    }).toList();
  }

  void toggleSeguirDestino(String destino) {
    final actual = Set<String>.from(destinosSeguidosNotifier.value);
    if (actual.contains(destino)) {
      actual.remove(destino);
    } else {
      actual.add(destino);
    }
    destinosSeguidosNotifier.value = actual;
  }

  bool estaSiguiendoDestino(String destino) =>
      destinosSeguidosNotifier.value.contains(destino);

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

  void actualizarConfiguracion(ConfiguracionNotificaciones nuevaConfig) {
    configNotifier.value = nuevaConfig;
  }

  void dispose() {
    _refrescoTimer?.cancel();
  }
}
