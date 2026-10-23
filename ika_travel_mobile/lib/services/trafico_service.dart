import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/api_config.dart';
import '../models/navegacion_modelo.dart';
import '../models/trafico_modelo.dart';

/// Servicio especializado en consulta, análisis y gestión de tráfico e incidentes viales reales.
///
/// Implementa arquitectura con caché espacial/temporal (TTL 5 min), protección
/// contra consumo excesivo de cuota, manejo de errores de red y validación
/// estricta de rutas alternativas antes de proponer desvíos.
///
/// IMPORTANTE: Si no se configuran credenciales válidas, este servicio opera
/// en modo informativo sin inventar incidentes ni demoras simuladas.
class TraficoService {
  static final TraficoService _instancia = TraficoService._interno();
  factory TraficoService({http.Client? client, String? apiKey}) {
    if (client != null || apiKey != null) {
      return TraficoService._personalizado(client: client, apiKey: apiKey);
    }
    return _instancia;
  }

  TraficoService._interno() : _client = http.Client(), _apiKeyPersonalizada = null;

  TraficoService._personalizado({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKeyPersonalizada = apiKey;

  final http.Client _client;
  final String? _apiKeyPersonalizada;

  // ── Notificadores reactivos ────────────────────────────────────────────────
  final ValueNotifier<EstadoProveedorTrafico> estadoProveedorNotifier =
      ValueNotifier(EstadoProveedorTrafico.sinConfigurar);

  final ValueNotifier<List<IncidenteTrafico>> incidentesNotifier =
      ValueNotifier([]);

  final ValueNotifier<String> mensajeEstadoNotifier =
      ValueNotifier('Tráfico en vivo no configurado');

  final ValueNotifier<DateTime?> ultimaActualizacionNotifier =
      ValueNotifier(null);

  final ValueNotifier<List<IncidenteTrafico>> incidentesEnRutaNotifier =
      ValueNotifier([]);

  // ── Caché y control de frecuencia ──────────────────────────────────────────
  List<IncidenteTrafico> _cacheIncidentes = [];
  DateTime? _ultimoMomentoConsulta;
  String? _ultimoBboxConsultado;

  /// Duración de validez del caché en memoria (5 minutos)
  /// Protege el límite gratuito de 2.500 req/día de TomTom
  static const Duration duracionCache = Duration(minutes: 5);

  /// Tiempo de espera límite para solicitudes de red
  static const Duration timeoutRed = Duration(seconds: 7);

  String get apiKeyActual =>
      _apiKeyPersonalizada ?? ApiConfig.tomtomApiKey;

  bool get tieneCredenciales => apiKeyActual.trim().isNotEmpty;

  /// Retorna la clave enmascarada para evitar exponer secretos en UI o depuración
  String get apiKeyEnmascarada {
    final k = apiKeyActual.trim();
    if (k.isEmpty) return '(no configurada)';
    if (k.length <= 8) return '********';
    return '${k.substring(0, 4)}...${k.substring(k.length - 4)}';
  }

  /// Indica si la caché actual contiene datos verificados dentro de la ventana de validez
  bool get datosSonRecientes {
    if (!tieneCredenciales || _ultimoMomentoConsulta == null) return false;
    return DateTime.now().difference(_ultimoMomentoConsulta!) <= duracionCache;
  }

  /// Consulta incidentes viales reales para una caja delimitadora (bbox)
  ///
  /// Si no hay clave API configurada, reporta [EstadoProveedorTrafico.sinConfigurar]
  /// sin lanzar excepciones ni inventar datos.
  Future<List<IncidenteTrafico>> obtenerIncidentes({
    String bbox = ApiConfig.bboxIca,
    bool forzarRecarga = false,
  }) async {
    // 1. Verificación de credenciales
    if (!tieneCredenciales) {
      estadoProveedorNotifier.value = EstadoProveedorTrafico.sinConfigurar;
      mensajeEstadoNotifier.value =
          'Tráfico en vivo pendiente de configuración (requiere API Key)';
      incidentesNotifier.value = [];
      _cacheIncidentes = [];
      return [];
    }

    // 2. Comprobar validez de caché
    final ahora = DateTime.now();
    if (!forzarRecarga &&
        _ultimoMomentoConsulta != null &&
        _ultimoBboxConsultado == bbox &&
        ahora.difference(_ultimoMomentoConsulta!) < duracionCache) {
      debugPrint(
          '[TraficoService] Retornando ${_cacheIncidentes.length} incidentes desde caché espacial');
      return _cacheIncidentes;
    }

    // 3. Ejecutar petición remota protegida
    estadoProveedorNotifier.value = EstadoProveedorTrafico.cargando;
    mensajeEstadoNotifier.value = 'Consultando incidentes viales reales…';

    try {
      final url = ApiConfig.tomtomIncidentDetailsUri(
        apiKey: apiKeyActual,
        bbox: bbox,
      );

      final response = await _client.get(url).timeout(timeoutRed);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rawIncidents = data['incidents'] as List<dynamic>? ?? [];

        final List<IncidenteTrafico> incidentesParseados = [];
        for (final item in rawIncidents) {
          if (item is Map<String, dynamic>) {
            try {
              incidentesParseados.add(IncidenteTrafico.fromTomTomJson(item));
            } catch (e) {
              debugPrint('[TraficoService] Error al parsear incidente individual: $e');
            }
          }
        }

        _cacheIncidentes = incidentesParseados;
        _ultimoMomentoConsulta = ahora;
        _ultimoBboxConsultado = bbox;

        incidentesNotifier.value = incidentesParseados;
        ultimaActualizacionNotifier.value = ahora;

        if (incidentesParseados.isEmpty) {
          estadoProveedorNotifier.value = EstadoProveedorTrafico.sinIncidentes;
          mensajeEstadoNotifier.value = 'Vías de Ica sin incidentes confirmados';
        } else {
          estadoProveedorNotifier.value = EstadoProveedorTrafico.conectado;
          mensajeEstadoNotifier.value =
              '${incidentesParseados.length} incidente(s) vial(es) confirmado(s)';
        }

        return incidentesParseados;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        estadoProveedorNotifier.value = EstadoProveedorTrafico.cuotaExcedida;
        mensajeEstadoNotifier.value =
            'Clave de TomTom inválida o no autorizada (${response.statusCode})';
        return _cacheIncidentes;
      } else if (response.statusCode == 429) {
        estadoProveedorNotifier.value = EstadoProveedorTrafico.cuotaExcedida;
        mensajeEstadoNotifier.value =
            'Límite de solicitudes de tráfico superado (429)';
        return _cacheIncidentes;
      } else if (response.statusCode == 400) {
        estadoProveedorNotifier.value = EstadoProveedorTrafico.errorConexion;
        mensajeEstadoNotifier.value =
            'Parámetros de consulta de tráfico no válidos (400)';
        return _cacheIncidentes;
      } else {
        estadoProveedorNotifier.value = EstadoProveedorTrafico.errorConexion;
        mensajeEstadoNotifier.value =
            'Servicio de tráfico no disponible temporalmente (${response.statusCode})';
        return _cacheIncidentes;
      }
    } on TimeoutException {
      estadoProveedorNotifier.value = EstadoProveedorTrafico.errorConexion;
      mensajeEstadoNotifier.value = 'Tiempo de espera agotado al consultar tráfico';
      return _cacheIncidentes;
    } catch (e) {
      estadoProveedorNotifier.value = EstadoProveedorTrafico.errorConexion;
      mensajeEstadoNotifier.value = 'Error de conexión con el proveedor de tráfico';
      debugPrint('[TraficoService] Error de red: $e');
      return _cacheIncidentes;
    }
  }

  /// Detecta cuáles incidentes conocidos intersecan o afectan la polilínea de la ruta
  List<IncidenteTrafico> detectarIncidentesEnRuta(
    List<LatLng> geometriaRuta, {
    double? umbralPersonalizadoMetros,
  }) {
    if (geometriaRuta.isEmpty || _cacheIncidentes.isEmpty) {
      incidentesEnRutaNotifier.value = [];
      return [];
    }

    final afectados = _cacheIncidentes.where((incidente) {
      return incidente.afectaRuta(
        geometriaRuta,
        umbralPersonalizadoMetros: umbralPersonalizadoMetros,
      );
    }).toList();

    incidentesEnRutaNotifier.value = afectados;
    return afectados;
  }

  /// Verifica si una geometría de ruta pasa por algún bloqueo o cierre total
  bool rutaTieneBloqueosTotales(List<LatLng> geometriaRuta) {
    final incidentes = detectarIncidentesEnRuta(geometriaRuta);
    return incidentes.any((inc) => inc.esBloqueoCompleto);
  }

  /// Valida rutas alternativas para encontrar una que evite bloqueos viales confirmados.
  ///
  /// Regla de seguridad estricta: Si no se dispone de datos recientes y confirmados de tráfico,
  /// no se afirma que una ruta alternativa esté libre de bloqueos ni se autoriza el cambio.
  RutaNavegacion? encontrarMejorAlternativaSinBloqueos({
    required List<RutaNavegacion> rutasCandidatas,
    required RutaNavegacion rutaActual,
  }) {
    if (!datosSonRecientes) return null;
    if (rutasCandidatas.isEmpty) return null;

    for (final candidata in rutasCandidatas) {
      if (candidata == rutaActual) continue;

      // Evaluar si la candidata tiene bloqueos
      final bloqueada = rutaTieneBloqueosTotales(candidata.polilineaCompleta);
      if (!bloqueada) {
        return candidata;
      }
    }

    // Ninguna candidata evita el bloqueo o no hay alternativas
    return null;
  }

  /// Limpia el caché en memoria para pruebas o reinicio
  void limpiarCache() {
    _cacheIncidentes = [];
    _ultimoMomentoConsulta = null;
    _ultimoBboxConsultado = null;
    incidentesNotifier.value = [];
    incidentesEnRutaNotifier.value = [];
    estadoProveedorNotifier.value = EstadoProveedorTrafico.sinConfigurar;
    mensajeEstadoNotifier.value = 'Tráfico en vivo no configurado';
    ultimaActualizacionNotifier.value = null;
  }
}
