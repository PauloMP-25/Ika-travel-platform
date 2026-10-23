import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/itinerario_modelo.dart';
import '../models/navegacion_modelo.dart';
import '../models/trafico_modelo.dart';
import 'osrm_service.dart';
import 'trafico_service.dart';

/// Servicio orquestador de navegación vehicular en tiempo real.
///
/// Gestiona la lectura satelital GPS continua, orientación, avance paso a paso,
/// avisos de voz TTS en español multi-etapa, detección de desvíos con filtrado
/// anti-jitter, recálculo automático, itinerarios multi-destino, rutas alternativas,
/// progreso temporal y control seguro del ciclo de vida.
class NavegacionService {
  static final NavegacionService _instancia = NavegacionService._interno();
  factory NavegacionService() => _instancia;
  NavegacionService._interno() {
    _inicializarTts();
  }

  final _osrm = OsrmService();
  final FlutterTts _tts = FlutterTts();

  StreamSubscription<Position>? _posicionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  Timer? _timerSimulacionPrueba;
  Timer? _watchdogGpsTimer;
  Timer? _timerCronometroViaje;

  // ── Notificadores reactivos ────────────────────────────────────────────────
  final ValueNotifier<EstadoGPS> estadoGpsNotifier =
      ValueNotifier(EstadoGPS.iniciando);
  final ValueNotifier<LatLng?> posicionActualNotifier = ValueNotifier(null);
  final ValueNotifier<double> rumboActualNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> velocidadKmhNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> precisionMetrosNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> esUbicacionRealNotifier = ValueNotifier(false);
  final ValueNotifier<int> pasoActualIndiceNotifier = ValueNotifier(0);
  final ValueNotifier<double> distanciaProximoGiroMetrosNotifier =
      ValueNotifier(0.0);
  final ValueNotifier<double> distanciaRestanteTotalMetrosNotifier =
      ValueNotifier(0.0);
  final ValueNotifier<double> tiempoRestanteTotalSegundosNotifier =
      ValueNotifier(0.0);
  final ValueNotifier<int> tiempoTranscurridoSegundosNotifier =
      ValueNotifier(0);
  final ValueNotifier<String> horaEstimadaLlegadaNotifier =
      ValueNotifier('');
  final ValueNotifier<bool> vozSilenciadaNotifier = ValueNotifier(false);
  final ValueNotifier<bool> recalculandoRutaNotifier = ValueNotifier(false);
  final ValueNotifier<String> mensajeRecalculoNotifier = ValueNotifier('');
  final ValueNotifier<RutaNavegacion?> rutaActivaNotifier = ValueNotifier(null);
  final ValueNotifier<List<RutaNavegacion>> rutasAlternativasNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<PuntoItinerario>> paradasItinerarioNotifier =
      ValueNotifier([]);
  final ValueNotifier<int> indiceParadaActualNotifier = ValueNotifier(0);
  final ValueNotifier<PuntoItinerario?> paradaAlcanzadaNotifier =
      ValueNotifier(null);
  final ValueNotifier<IncidenteTrafico?> alertaIncidenteActivoNotifier =
      ValueNotifier(null);
  final ValueNotifier<RutaNavegacion?> rutaAlternativaSugeridaNotifier =
      ValueNotifier(null);

  final _trafico = TraficoService();
  final Set<String> _avisosIncidentesHablados = {};

  // Registro de etapas habladas para evitar repetición
  final Map<int, Set<int>> _etapasHabladasPorPaso = {};
  String _ultimoMensajeHablado = '';
  DateTime _ultimoMomentoHablado = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _momentoInicioViaje;

  // Parámetros y filtros para detección de desvíos y llegadas
  double _umbralDesvioMetros = 45.0; // Configurable (por defecto 45 m)
  double _umbralLlegadaMetros = 30.0; // Configurable (por defecto 30 m)
  int _conteoDesviosConsecutivos = 0;
  int _conteoLlegadasConsecutivas = 0;
  DateTime _ultimoMomentoRecalculo = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _ultimaLecturaGps;

  double get umbralDesvioMetros => _umbralDesvioMetros;
  set umbralDesvioMetros(double valor) {
    if (valor >= 20.0 && valor <= 150.0) {
      _umbralDesvioMetros = valor;
    }
  }

  double get umbralLlegadaMetros => _umbralLlegadaMetros;
  set umbralLlegadaMetros(double valor) {
    if (valor >= 10.0 && valor <= 100.0) {
      _umbralLlegadaMetros = valor;
    }
  }

  PuntoItinerario? get paradaActual {
    final paradas = paradasItinerarioNotifier.value;
    final idx = indiceParadaActualNotifier.value;
    if (idx < paradas.length) {
      return paradas[idx];
    }
    return null;
  }

  bool get hayMasDestinos =>
      indiceParadaActualNotifier.value <
      paradasItinerarioNotifier.value.length - 1;

  // ── Inicialización y Control de Voz (TTS) ──────────────────────────────────
  bool _estaHablando = false;
  Timer? _timerSeguridadVoz;
  final List<String> _colaVoz = [];

  Future<void> _inicializarTts() async {
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.48); // Velocidad natural y clara
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _estaHablando = true;
      });
      _tts.setCompletionHandler(() {
        _estaHablando = false;
        _procesarColaVoz();
      });
      _tts.setCancelHandler(() {
        _estaHablando = false;
        _procesarColaVoz();
      });
      _tts.setErrorHandler((_) {
        _estaHablando = false;
        _procesarColaVoz();
      });
    } catch (e) {
      debugPrint('[NavegacionService] TTS fallback/init: $e');
    }
  }

  void _procesarColaVoz() {
    _timerSeguridadVoz?.cancel();
    _estaHablando = false;
    if (_colaVoz.isEmpty || vozSilenciadaNotifier.value) return;

    final siguiente = _colaVoz.removeAt(0);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!vozSilenciadaNotifier.value && !_estaHablando) {
        _hablarTexto(siguiente);
      }
    });
  }

  Future<void> _detenerTtsSeguro() async {
    _timerSeguridadVoz?.cancel();
    _colaVoz.clear();
    _estaHablando = false;
    try {
      await _tts.stop();
    } catch (_) {
      // Ignorar si el plugin nativo no está registrado (entorno headless de tests)
    }
  }

  /// Alterna el estado de silencio de las indicaciones por voz
  void alternarSilencioVoz() {
    vozSilenciadaNotifier.value = !vozSilenciadaNotifier.value;
    if (vozSilenciadaNotifier.value) {
      _detenerTtsSeguro();
    } else {
      anunciarVoz('Instrucciones por voz activadas', forzar: true);
    }
  }

  Future<void> _hablarTexto(String texto) async {
    _estaHablando = true;
    _ultimoMensajeHablado = texto;
    _ultimoMomentoHablado = DateTime.now();

    // Fallback de seguridad: si el motor nativo TTS no dispara completionHandler,
    // liberamos _estaHablando tras la duración estimada de la locución en español.
    final palabras = texto.split(' ').length;
    final duracionEstimadaMs = math.max(2600, palabras * 420 + 800);
    _timerSeguridadVoz?.cancel();
    _timerSeguridadVoz = Timer(Duration(milliseconds: duracionEstimadaMs), () {
      if (_estaHablando) {
        _estaHablando = false;
        _procesarColaVoz();
      }
    });

    try {
      await _tts.speak(texto);
    } catch (e) {
      debugPrint('[NavegacionService] Error emitiendo voz: $e');
      _estaHablando = false;
      _procesarColaVoz();
    }
  }

  /// Emite una indicación de audio en español sin cortar frases en curso
  Future<void> anunciarVoz(String texto, {bool forzar = false}) async {
    if (vozSilenciadaNotifier.value) return;
    final limpio = texto.trim();
    if (limpio.isEmpty) return;

    final ahora = DateTime.now();
    // Evitar repetir la misma indicación idéntica en menos de 7 segundos
    if (!forzar &&
        _ultimoMensajeHablado == limpio &&
        ahora.difference(_ultimoMomentoHablado).inSeconds < 7) {
      return;
    }

    if (forzar) {
      _colaVoz.clear();
      _timerSeguridadVoz?.cancel();
      try {
        await _tts.stop();
      } catch (_) {}
      await _hablarTexto(limpio);
      return;
    }

    if (_estaHablando) {
      // Si la voz está ocupada pronunciando una maniobra, encolar en vez de cortarla
      if (!_colaVoz.contains(limpio)) {
        if (_colaVoz.length >= 2) {
          _colaVoz.removeLast(); // Mantener fresca la cola
        }
        _colaVoz.add(limpio);
      }
    } else {
      await _hablarTexto(limpio);
    }
  }

  // ── Ciclo de Navegación ───────────────────────────────────────────────────

  /// Inicia el seguimiento de navegación con una [RutaNavegacion], opcionalmente con
  /// múltiples [paradasItinerario] y [rutasAlternativas].
  Future<void> iniciarNavegacion({
    required RutaNavegacion ruta,
    List<PuntoItinerario>? paradasItinerario,
    List<RutaNavegacion>? rutasAlternativas,
    bool usarSimulacionPrueba = false,
  }) async {
    detenerNavegacion();

    rutaActivaNotifier.value = ruta;
    rutasAlternativasNotifier.value =
        (rutasAlternativas != null && rutasAlternativas.isNotEmpty)
            ? rutasAlternativas
            : [ruta];

    if (paradasItinerario != null && paradasItinerario.isNotEmpty) {
      paradasItinerarioNotifier.value = List.unmodifiable(paradasItinerario);
    } else {
      paradasItinerarioNotifier.value = [
        PuntoItinerario(
          id: 'dest_0',
          nombre: ruta.nombreDestino,
          descripcion: 'Destino seleccionado para navegación',
          coordenadas: ruta.destino,
        ),
      ];
    }
    indiceParadaActualNotifier.value = 0;
    paradaAlcanzadaNotifier.value = null;
    _conteoLlegadasConsecutivas = 0;

    pasoActualIndiceNotifier.value = 0;
    _etapasHabladasPorPaso.clear();
    distanciaRestanteTotalMetrosNotifier.value = ruta.distanciaTotalMetros;
    tiempoRestanteTotalSegundosNotifier.value = ruta.duracionTotalSegundos;

    // Iniciar cronómetro de viaje real transcurrido
    _momentoInicioViaje = DateTime.now();
    tiempoTranscurridoSegundosNotifier.value = 0;
    _timerCronometroViaje?.cancel();
    _timerCronometroViaje = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_momentoInicioViaje != null) {
        tiempoTranscurridoSegundosNotifier.value =
            DateTime.now().difference(_momentoInicioViaje!).inSeconds;
      }
    });

    _calcularHoraEstimadaLlegada(ruta.duracionTotalSegundos);
    _verificarIncidentesEnRuta(ruta);

    if (ruta.pasos.isNotEmpty) {
      distanciaProximoGiroMetrosNotifier.value =
          ruta.pasos.first.distanciaMetros;
      anunciarVoz(ruta.pasos.first.instruccionEspanol);
      _marcarEtapaHablada(0, 1);
    }

    if (usarSimulacionPrueba) {
      _iniciarSimulacionRecorridoPrueba(ruta);
      return;
    }

    await _conectarGpsReal();
    _iniciarWatchdogSenalGps();
  }

  /// Selecciona una ruta alternativa para la navegación en curso
  void seleccionarRutaAlternativa(RutaNavegacion nuevaRuta) {
    rutaActivaNotifier.value = nuevaRuta;
    final actualizadas = rutasAlternativasNotifier.value.map((r) {
      return r.copyWith(esSeleccionada: r.id == nuevaRuta.id);
    }).toList();
    rutasAlternativasNotifier.value = actualizadas;

    pasoActualIndiceNotifier.value = 0;
    _etapasHabladasPorPaso.clear();
    distanciaRestanteTotalMetrosNotifier.value = nuevaRuta.distanciaTotalMetros;
    tiempoRestanteTotalSegundosNotifier.value = nuevaRuta.duracionTotalSegundos;
    _calcularHoraEstimadaLlegada(nuevaRuta.duracionTotalSegundos);

    if (nuevaRuta.pasos.isNotEmpty) {
      distanciaProximoGiroMetrosNotifier.value =
          nuevaRuta.pasos.first.distanciaMetros;
      anunciarVoz(
        'Ruta cambiada a ${nuevaRuta.etiqueta}. ${nuevaRuta.pasos.first.instruccionEspanol}',
        forzar: true,
      );
      _marcarEtapaHablada(0, 1);
    }

    _verificarIncidentesEnRuta(nuevaRuta);
  }

  /// Desvía el viaje por la ruta alternativa sugerida que evita un bloqueo confirmado.
  /// Retorna true si se ejecutó el cambio exitosamente.
  Future<bool> desviarPorRutaAlternativa() async {
    final sugerida = rutaAlternativaSugeridaNotifier.value;
    if (sugerida == null) return false;

    seleccionarRutaAlternativa(sugerida);
    alertaIncidenteActivoNotifier.value = null;
    rutaAlternativaSugeridaNotifier.value = null;
    anunciarVoz(
      'Desviando por ${sugerida.etiqueta} para evitar incidente reportado',
      forzar: true,
    );
    return true;
  }

  /// Calcula dinámicamente un desvío por calles alternas aledañas para sortear
  /// un cierre total de vía reportado en tiempo real en Ica.
  Future<bool> buscarYDesviarPorCallesAlternas() async {
    final ruta = rutaActivaNotifier.value;
    final incidente = alertaIncidenteActivoNotifier.value;
    if (ruta == null || incidente == null) return false;

    recalculandoRutaNotifier.value = true;
    mensajeRecalculoNotifier.value =
        'Buscando desvío seguro por calles aledañas para evitar ${incidente.viaAfectada}…';

    final origen = posicionActualNotifier.value ?? ruta.origen;
    final destino = ruta.destino;

    // Generar puntos de desvío ortogonales a la zona afectada (~350-500m hacia avenidas paralelas)
    final offsets = [
      LatLng(incidente.coordenadas.latitude + 0.0035, incidente.coordenadas.longitude + 0.0025),
      LatLng(incidente.coordenadas.latitude - 0.0035, incidente.coordenadas.longitude - 0.0025),
      LatLng(incidente.coordenadas.latitude + 0.0040, incidente.coordenadas.longitude - 0.0030),
      LatLng(incidente.coordenadas.latitude - 0.0040, incidente.coordenadas.longitude + 0.0030),
    ];

    for (final waypoint in offsets) {
      final rutaDesvio = await OsrmService().obtenerRutaConDesvio(
        origen: origen,
        destino: destino,
        puntoDesvio: waypoint,
        nombreDestino: ruta.nombreDestino,
        etiqueta: 'Vía alterna despejada',
      );

      if (rutaDesvio != null) {
        // Confirmar que el desvío no atraviese el bloqueo
        final tieneBloqueo = _trafico.rutaTieneBloqueosTotales(rutaDesvio.polilineaCompleta);
        if (!tieneBloqueo) {
          rutaAlternativaSugeridaNotifier.value = rutaDesvio;
          recalculandoRutaNotifier.value = false;
          await desviarPorRutaAlternativa();
          return true;
        }
      }
    }

    recalculandoRutaNotifier.value = false;
    return false;
  }

  /// Busca en segundo plano una ruta alternativa por vías adyacentes ante cierres totales
  void _prepararDesvioEnSegundoPlano(RutaNavegacion ruta, IncidenteTrafico incidente) async {
    try {
      final origen = posicionActualNotifier.value ?? ruta.origen;
      final destino = ruta.destino;

      final offsets = [
        LatLng(incidente.coordenadas.latitude + 0.0035, incidente.coordenadas.longitude + 0.0025),
        LatLng(incidente.coordenadas.latitude - 0.0035, incidente.coordenadas.longitude - 0.0025),
        LatLng(incidente.coordenadas.latitude + 0.0040, incidente.coordenadas.longitude),
        LatLng(incidente.coordenadas.latitude - 0.0040, incidente.coordenadas.longitude),
      ];

      for (final waypoint in offsets) {
        final rutaDesvio = await OsrmService().obtenerRutaConDesvio(
          origen: origen,
          destino: destino,
          puntoDesvio: waypoint,
          nombreDestino: ruta.nombreDestino,
          etiqueta: 'Vía alterna despejada',
        );

        if (rutaDesvio != null) {
          final tieneBloqueo = _trafico.rutaTieneBloqueosTotales(rutaDesvio.polilineaCompleta);
          if (!tieneBloqueo) {
            // Solo asignar si la alerta sigue activa
            if (alertaIncidenteActivoNotifier.value?.id == incidente.id) {
              rutaAlternativaSugeridaNotifier.value = rutaDesvio;
            }
            break;
          }
        }
      }
    } catch (_) {}
  }

  /// Descarta la alerta visual de incidente actual sin alterar la ruta
  void descartarAlertaIncidente() {
    alertaIncidenteActivoNotifier.value = null;
    rutaAlternativaSugeridaNotifier.value = null;
  }

  /// Verifica si la ruta activa tiene incidentes confirmados reportados
  void _verificarIncidentesEnRuta(RutaNavegacion ruta) {
    final incidentes = _trafico.detectarIncidentesEnRuta(ruta.polilineaCompleta);
    if (incidentes.isNotEmpty) {
      // Ordenar por criticidad (bloqueos y severidad alta primero)
      final listaOrdenada = List<IncidenteTrafico>.from(incidentes)
        ..sort((a, b) => b.severidad.index.compareTo(a.severidad.index));

      final incidenteCritico = listaOrdenada.first;
      alertaIncidenteActivoNotifier.value = incidenteCritico;

      // Validar si alguna alternativa existente evita el bloqueo
      final altSinBloqueo = _trafico.encontrarMejorAlternativaSinBloqueos(
        rutasCandidatas: rutasAlternativasNotifier.value,
        rutaActual: ruta,
      );
      rutaAlternativaSugeridaNotifier.value = altSinBloqueo;

      // Si no existe alternativa previa y es un bloqueo, calcular desvío por vías alternas
      if (altSinBloqueo == null && incidenteCritico.esBloqueoCompleto) {
        _prepararDesvioEnSegundoPlano(ruta, incidenteCritico);
      }

      // Anunciar por voz una sola vez por cada incidente
      if (!_avisosIncidentesHablados.contains(incidenteCritico.id)) {
        _avisosIncidentesHablados.add(incidenteCritico.id);
        final aviso = incidenteCritico.esBloqueoCompleto
            ? 'Atención: ${incidenteCritico.nombreTipoEspanol} reportado adelante en ${incidenteCritico.viaAfectada}.'
            : 'Alerta vial: ${incidenteCritico.nombreTipoEspanol} en ${incidenteCritico.viaAfectada}.';
        anunciarVoz(aviso, forzar: true);
      }
    } else {
      alertaIncidenteActivoNotifier.value = null;
      rutaAlternativaSugeridaNotifier.value = null;
    }
  }

  /// Avanza al siguiente destino del itinerario si existen más paradas pendientes
  Future<bool> avanzarASiguienteParada() async {
    if (!hayMasDestinos) return false;

    final nuevoIndice = indiceParadaActualNotifier.value + 1;
    indiceParadaActualNotifier.value = nuevoIndice;
    paradaAlcanzadaNotifier.value = null;
    _conteoLlegadasConsecutivas = 0;

    final paradaObjetivo = paradasItinerarioNotifier.value[nuevoIndice];
    final origenActual = posicionActualNotifier.value ??
        rutaActivaNotifier.value?.destino ??
        paradaObjetivo.coordenadas;

    recalculandoRutaNotifier.value = true;
    mensajeRecalculoNotifier.value =
        'Calculando ruta hacia ${paradaObjetivo.nombre}…';
    anunciarVoz('Continuando hacia ${paradaObjetivo.nombre}', forzar: true);

    try {
      final nuevasRutas = await _osrm.obtenerRutasConAlternativas(
        origen: origenActual,
        destino: paradaObjetivo.coordenadas,
        nombreDestino: paradaObjetivo.nombre,
        incluirAlternativas: true,
      );

      rutasAlternativasNotifier.value = nuevasRutas;
      final nuevaRutaActiva = nuevasRutas.first;
      rutaActivaNotifier.value = nuevaRutaActiva;
      pasoActualIndiceNotifier.value = 0;
      _etapasHabladasPorPaso.clear();
      distanciaRestanteTotalMetrosNotifier.value =
          nuevaRutaActiva.distanciaTotalMetros;
      tiempoRestanteTotalSegundosNotifier.value =
          nuevaRutaActiva.duracionTotalSegundos;
      _calcularHoraEstimadaLlegada(nuevaRutaActiva.duracionTotalSegundos);

      if (nuevaRutaActiva.pasos.isNotEmpty) {
        distanciaProximoGiroMetrosNotifier.value =
            nuevaRutaActiva.pasos.first.distanciaMetros;
        anunciarVoz(
          nuevaRutaActiva.pasos.first.instruccionEspanol,
          forzar: true,
        );
        _marcarEtapaHablada(0, 1);
      }
      return true;
    } catch (e) {
      debugPrint('[NavegacionService] Error avanzando a parada: $e');
      mensajeRecalculoNotifier.value = 'Ruta no disponible por red';
      return false;
    } finally {
      recalculandoRutaNotifier.value = false;
    }
  }

  void _calcularHoraEstimadaLlegada(double duracionSegundos) {
    final llegada =
        DateTime.now().add(Duration(seconds: duracionSegundos.round()));
    final h = llegada.hour.toString().padLeft(2, '0');
    final m = llegada.minute.toString().padLeft(2, '0');
    horaEstimadaLlegadaNotifier.value = '$h:$m';
  }

  /// Detiene la navegación, cancela streams GPS, timers y recursos de voz
  void detenerNavegacion() {
    _posicionSubscription?.cancel();
    _posicionSubscription = null;
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
    _timerSimulacionPrueba?.cancel();
    _timerSimulacionPrueba = null;
    _watchdogGpsTimer?.cancel();
    _watchdogGpsTimer = null;
    _timerCronometroViaje?.cancel();
    _timerCronometroViaje = null;

    _detenerTtsSeguro();
    _conteoDesviosConsecutivos = 0;
    _conteoLlegadasConsecutivas = 0;
    _etapasHabladasPorPaso.clear();
    paradaAlcanzadaNotifier.value = null;
    alertaIncidenteActivoNotifier.value = null;
    rutaAlternativaSugeridaNotifier.value = null;
    _avisosIncidentesHablados.clear();
    esUbicacionRealNotifier.value = false;
    estadoGpsNotifier.value = EstadoGPS.desactivado;
  }


  // ── Manejo de Permisos y Conexión GPS Real ─────────────────────────────────

  /// Reintenta la conexión GPS (por ejemplo al volver de los ajustes del sistema)
  Future<void> reintentarConexionGps() async {
    final ruta = rutaActivaNotifier.value;
    if (ruta == null) return;
    await _conectarGpsReal();
  }

  Future<void> _conectarGpsReal() async {
    estadoGpsNotifier.value = EstadoGPS.iniciando;
    esUbicacionRealNotifier.value = false;

    try {
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        estadoGpsNotifier.value = EstadoGPS.desactivado;
        _escucharEstadoServicioUbicacion();
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          estadoGpsNotifier.value = EstadoGPS.permisoDenegado;
          return;
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        estadoGpsNotifier.value = EstadoGPS.permisoDenegadoPermanente;
        return;
      }

      estadoGpsNotifier.value = EstadoGPS.buscandoSenal;
      _escucharEstadoServicioUbicacion();

      // Obtener posición inicial
      final posicionInicial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      _procesarNuevaPosicion(posicionInicial);
      estadoGpsNotifier.value = EstadoGPS.activo;
      esUbicacionRealNotifier.value = true;
      _ultimaLecturaGps = DateTime.now();

      // Escuchar stream continuo con parámetros optimizados para conducción
      _posicionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3, // Actualizar cada 3 metros
        ),
      ).listen(
        (pos) {
          _ultimaLecturaGps = DateTime.now();
          if (estadoGpsNotifier.value != EstadoGPS.activo) {
            estadoGpsNotifier.value = EstadoGPS.activo;
          }
          esUbicacionRealNotifier.value = true;
          _procesarNuevaPosicion(pos);
        },
        onError: (e) {
          debugPrint('[NavegacionService] Error en stream GPS: $e');
          estadoGpsNotifier.value = EstadoGPS.errorConexion;
          esUbicacionRealNotifier.value = false;
        },
      );
    } catch (e) {
      debugPrint('[NavegacionService] Error inicializando GPS: $e');
      estadoGpsNotifier.value = EstadoGPS.errorConexion;
      esUbicacionRealNotifier.value = false;
    }
  }

  /// Escucha si el usuario apaga o prende el GPS en la barra de ajustes del celular
  void _escucharEstadoServicioUbicacion() {
    _serviceStatusSubscription?.cancel();
    try {
      _serviceStatusSubscription =
          Geolocator.getServiceStatusStream().listen((status) {
        if (status == ServiceStatus.disabled) {
          estadoGpsNotifier.value = EstadoGPS.desactivado;
          esUbicacionRealNotifier.value = false;
          anunciarVoz('Señal de ubicación desactivada');
        } else if (status == ServiceStatus.enabled) {
          estadoGpsNotifier.value = EstadoGPS.buscandoSenal;
          _conectarGpsReal();
        }
      });
    } catch (_) {}
  }

  /// Watchdog: detecta si no se reciben datos GPS durante más de 12 segundos
  void _iniciarWatchdogSenalGps() {
    _watchdogGpsTimer?.cancel();
    _watchdogGpsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (estadoGpsNotifier.value == EstadoGPS.activo &&
          _ultimaLecturaGps != null) {
        final sinDatosSegundos =
            DateTime.now().difference(_ultimaLecturaGps!).inSeconds;
        if (sinDatosSegundos > 12) {
          estadoGpsNotifier.value = EstadoGPS.buscandoSenal;
        }
      }
    });
  }

  // ── Procesamiento de Posición GPS ──────────────────────────────────────────

  /// Procesa cada lectura de satélite GPS
  void _procesarNuevaPosicion(Position pos) {
    final nuevaCoord = LatLng(pos.latitude, pos.longitude);
    final coordAnterior = posicionActualNotifier.value;

    posicionActualNotifier.value = nuevaCoord;
    precisionMetrosNotifier.value = pos.accuracy;
    velocidadKmhNotifier.value =
        math.max(0.0, (pos.speed * 3.6)); // m/s a km/h

    // Cálculo del rumbo (heading)
    double nuevoRumbo = pos.heading;
    if (nuevoRumbo <= 0 && coordAnterior != null) {
      nuevoRumbo = _calcularRumbo(coordAnterior, nuevaCoord);
    }
    if (nuevoRumbo >= 0) {
      rumboActualNotifier.value = nuevoRumbo;
    }

    final ruta = rutaActivaNotifier.value;
    if (ruta == null) return;

    // 1. Filtrado de precisión: no recalcular si la lectura es muy imprecisa (> 50m)
    final precisionAceptable = pos.accuracy <= 50.0;

    if (precisionAceptable) {
      _verificarDesvioYRecalcular(nuevaCoord, ruta);
    }

    // 2. Actualizar progreso del paso actual y métricas de viaje hacia el destino
    _actualizarProgresoPasos(nuevaCoord, ruta);
  }

  // ── Detección de Desvíos Anti-Falsos Positivos y Recálculo ──────────────────

  /// Calcula la distancia perpendicular del vehículo a la polilínea para detectar desvíos
  void _verificarDesvioYRecalcular(LatLng posicionActual, RutaNavegacion ruta) {
    if (recalculandoRutaNotifier.value) return;

    // Throttle: no permitir recálculos con menos de 8 segundos de diferencia
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoMomentoRecalculo).inSeconds < 8) return;

    final distMinimaRuta =
        _distanciaMinimaAPolilinea(posicionActual, ruta.polilineaCompleta);

    if (distMinimaRuta > _umbralDesvioMetros) {
      _conteoDesviosConsecutivos++;
      // Se requieren 2 lecturas consecutivas fuera de la ruta para confirmar desvío real
      if (_conteoDesviosConsecutivos >= 2) {
        _recalcularRutaPorDesvio(posicionActual, ruta);
      }
    } else {
      _conteoDesviosConsecutivos = 0;
    }
  }

  /// Recalcula la ruta con OSRM desde la posición actual hacia el destino
  Future<void> _recalcularRutaPorDesvio(
      LatLng posicionActual, RutaNavegacion rutaOriginal) async {
    recalculandoRutaNotifier.value = true;
    mensajeRecalculoNotifier.value = 'Buscando nueva ruta…';
    _conteoDesviosConsecutivos = 0;
    _ultimoMomentoRecalculo = DateTime.now();
    anunciarVoz('Recalculando ruta', forzar: true);

    try {
      final destActual = paradaActual?.coordenadas ?? rutaOriginal.destino;
      final nombreDestActual =
          paradaActual?.nombre ?? rutaOriginal.nombreDestino;

      final nuevasRutas = await _osrm.obtenerRutasConAlternativas(
        origen: posicionActual,
        destino: destActual,
        nombreDestino: nombreDestActual,
        incluirAlternativas: true,
      );

      rutasAlternativasNotifier.value = nuevasRutas;
      final nuevaRuta = nuevasRutas.first;
      rutaActivaNotifier.value = nuevaRuta;
      pasoActualIndiceNotifier.value = 0;
      _etapasHabladasPorPaso.clear();
      distanciaRestanteTotalMetrosNotifier.value =
          nuevaRuta.distanciaTotalMetros;
      tiempoRestanteTotalSegundosNotifier.value =
          nuevaRuta.duracionTotalSegundos;
      _calcularHoraEstimadaLlegada(nuevaRuta.duracionTotalSegundos);

      if (nuevaRuta.pasos.isNotEmpty) {
        distanciaProximoGiroMetrosNotifier.value =
            nuevaRuta.pasos.first.distanciaMetros;
        anunciarVoz(nuevaRuta.pasos.first.instruccionEspanol, forzar: true);
        _marcarEtapaHablada(0, 1);
      }

      _verificarIncidentesEnRuta(nuevaRuta);
    } catch (e) {
      debugPrint('[NavegacionService] Error al recalcular ruta: $e');
      mensajeRecalculoNotifier.value = 'Ruta no disponible por red';
    } finally {
      recalculandoRutaNotifier.value = false;
    }
  }

  // ── Actualización de Pasos y Voz Multi-etapa ────────────────────────────────

  /// Actualiza en qué paso se encuentra el vehículo y la distancia al próximo giro
  void _actualizarProgresoPasos(LatLng posicionActual, RutaNavegacion ruta) {
    int indiceActual = pasoActualIndiceNotifier.value;

    if (ruta.pasos.isNotEmpty && indiceActual < ruta.pasos.length) {
      final pasoActual = ruta.pasos[indiceActual];
      final finPaso = pasoActual.geometria.isNotEmpty
          ? pasoActual.geometria.last
          : pasoActual.maniobra.ubicacion;

      final distAlFinPaso = _distanciaHaversineMetros(posicionActual, finPaso);
      distanciaProximoGiroMetrosNotifier.value = distAlFinPaso;

      final proxPasoIndice = indiceActual + 1;
      final haySiguientePaso = proxPasoIndice < ruta.pasos.length;
      final esPasoCorto = pasoActual.distanciaMetros < 130;

      // ── Emisión de avisos por voz multi-etapa ─────────────────────────────
      // Etapa 2: Anticipación (100m a 250m) - Solo si la vía es suficientemente larga
      if (!esPasoCorto && distAlFinPaso <= 250 && distAlFinPaso > 90) {
        if (!_etapaYaHablada(indiceActual, 2)) {
          if (haySiguientePaso) {
            final proxPaso = ruta.pasos[proxPasoIndice];
            final redondeado = (distAlFinPaso / 50).round() * 50;
            anunciarVoz(
                'En $redondeado metros, ${proxPaso.instruccionEspanol.toLowerCase()}');
            _marcarEtapaHablada(indiceActual, 2);
          }
        }
      }
      // Etapa 3: Inmediata (15m a 45m)
      else if (distAlFinPaso <= 45 && distAlFinPaso > 15) {
        if (!_etapaYaHablada(indiceActual, 3)) {
          if (haySiguientePaso) {
            // Si hace menos de 4.5 segundos se anunció la Etapa 2 o la voz sigue activa,
            // no abrumamos repitiendo de golpe la misma dirección
            final ahora = DateTime.now();
            final segDesdeUltimo =
                ahora.difference(_ultimoMomentoHablado).inSeconds;
            if (!_estaHablando && segDesdeUltimo >= 4) {
              anunciarVoz(ruta.pasos[proxPasoIndice].instruccionEspanol);
            }
            _marcarEtapaHablada(indiceActual, 3);
          }
        }
      }

      // Avanzar de paso si ya superó el punto de giro actual (< 22 metros)
      if (distAlFinPaso < 22 && indiceActual < ruta.pasos.length - 1) {
        final nuevoIndice = indiceActual + 1;
        pasoActualIndiceNotifier.value = nuevoIndice;
        // Solo enunciar si no fue anunciado hace unos instantes en etapa 3
        if (!_etapaYaHablada(indiceActual, 3) && !_estaHablando) {
          final siguientePaso = ruta.pasos[nuevoIndice];
          anunciarVoz(siguientePaso.instruccionEspanol);
        }
      }
    }

    // Distancia y tiempo restante al destino objetivo de la etapa
    final destinoObjetivo = paradaActual?.coordenadas ?? ruta.destino;
    final nombreObjetivo = paradaActual?.nombre ?? ruta.nombreDestino;
    final distAlDestino =
        _distanciaHaversineMetros(posicionActual, destinoObjetivo);
    distanciaRestanteTotalMetrosNotifier.value = distAlDestino;

    // Velocidad media para ETA (mínimo 12.5 m/s = 45 km/h)
    final velMedia = velocidadKmhNotifier.value > 15
        ? (velocidadKmhNotifier.value / 3.6)
        : 12.5;
    final durRestante = distAlDestino / velMedia;
    tiempoRestanteTotalSegundosNotifier.value = durRestante;
    _calcularHoraEstimadaLlegada(durRestante);

    // ── Detección de llegada al destino con validación consecutiva (Anti-Jitter) ─
    if (distAlDestino <= _umbralLlegadaMetros) {
      _conteoLlegadasConsecutivas++;
      // Se requieren al menos 2 lecturas consecutivas dentro del umbral para confirmar llegada
      if (_conteoLlegadasConsecutivas >= 2) {
        if (paradaAlcanzadaNotifier.value == null) {
          final parada = paradaActual ??
              PuntoItinerario(
                id: 'dest_${indiceParadaActualNotifier.value}',
                nombre: nombreObjetivo,
                descripcion: 'Parada alcanzada',
                coordenadas: destinoObjetivo,
              );
          paradaAlcanzadaNotifier.value = parada;
          anunciarVoz('Ha llegado a su destino: ${parada.nombre}', forzar: true);
        }
      }
    } else {
      // Histéresis: si el vehículo se aleja más allá del umbral + 15 m, se resetea el contador
      if (distAlDestino > _umbralLlegadaMetros + 15.0) {
        _conteoLlegadasConsecutivas = 0;
      }
    }
  }

  bool _etapaYaHablada(int pasoIndice, int etapa) {
    return _etapasHabladasPorPaso[pasoIndice]?.contains(etapa) ?? false;
  }

  void _marcarEtapaHablada(int pasoIndice, int etapa) {
    _etapasHabladasPorPaso.putIfAbsent(pasoIndice, () => <int>{}).add(etapa);
  }

  // ── Modo Simulación de Recorrido de Prueba (Para Chrome/PC) ───────────────

  void _iniciarSimulacionRecorridoPrueba(RutaNavegacion ruta) {
    estadoGpsNotifier.value = EstadoGPS.modoSimulacionPrueba;
    esUbicacionRealNotifier.value = false;
    final puntos = ruta.polilineaCompleta;
    if (puntos.isEmpty) return;

    int indiceSim = 0;
    int ticksPausaVoz = 0;

    _timerSimulacionPrueba =
        Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (indiceSim >= puntos.length) {
        timer.cancel();
        anunciarVoz('Recorrido de prueba completado', forzar: true);
        return;
      }

      // Si el TTS está hablando una indicación por voz, pausar el avance
      // de coordenadas unos ticks para que no salte el giro antes de que la voz termine
      if (_estaHablando) {
        ticksPausaVoz++;
        if (ticksPausaVoz < 3) {
          // Mantener la posición y velocidad reducida mientras habla
          velocidadKmhNotifier.value = 24.0;
          return;
        }
      } else {
        ticksPausaVoz = 0;
      }

      final pActual = puntos[indiceSim];
      final pSiguiente = (indiceSim + 1 < puntos.length)
          ? puntos[indiceSim + 1]
          : pActual;
      final rumbo = _calcularRumbo(pActual, pSiguiente);

      posicionActualNotifier.value = pActual;
      rumboActualNotifier.value = rumbo;
      velocidadKmhNotifier.value = 38.0; // Velocidad de prueba realista y pausada
      precisionMetrosNotifier.value = 4.0;

      _actualizarProgresoPasos(pActual, ruta);
      indiceSim++;
    });
  }

  // ── Métodos para Pruebas Automatizadas ────────────────────────────────────

  @visibleForTesting
  int get conteoLlegadasConsecutivasTest => _conteoLlegadasConsecutivas;

  @visibleForTesting
  void setConteoLlegadasConsecutivasTest(int v) =>
      _conteoLlegadasConsecutivas = v;

  @visibleForTesting
  void procesarPosicionTest({
    required LatLng posicion,
    double precision = 8.0,
    double velocidadKmh = 40.0,
    double? rumbo,
  }) {
    final pos = Position(
      latitude: posicion.latitude,
      longitude: posicion.longitude,
      timestamp: DateTime.now(),
      accuracy: precision,
      altitude: 400.0,
      altitudeAccuracy: 5.0,
      heading: rumbo ?? 0.0,
      headingAccuracy: 2.0,
      speed: velocidadKmh / 3.6,
      speedAccuracy: 1.0,
    );
    _procesarNuevaPosicion(pos);
  }

  @visibleForTesting
  bool estaFueraDeRutaTest(LatLng pos, RutaNavegacion ruta) {
    final distMinima = _distanciaMinimaAPolilinea(pos, ruta.polilineaCompleta);
    return distMinima > _umbralDesvioMetros;
  }

  // ── Utilidades Geodésicas ─────────────────────────────────────────────────

  /// Calcula el ángulo de rumbo (bearing) en grados (0° a 360°) entre dos puntos
  double _calcularRumbo(LatLng origen, LatLng destino) {
    final lat1 = origen.latitude * math.pi / 180.0;
    final lat2 = destino.latitude * math.pi / 180.0;
    final dLon = (destino.longitude - origen.longitude) * math.pi / 180.0;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radianes = math.atan2(y, x);
    return (radianes * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Distancia Haversine en metros entre dos coordenadas
  double _distanciaHaversineMetros(LatLng a, LatLng b) {
    const r = 6371000.0; // Radio de la Tierra en metros
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180.0) *
            math.cos(b.latitude * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// Distancia mínima de un punto a una polilínea en metros
  double _distanciaMinimaAPolilinea(LatLng punto, List<LatLng> polilinea) {
    if (polilinea.isEmpty) return double.infinity;
    if (polilinea.length == 1) {
      return _distanciaHaversineMetros(punto, polilinea.first);
    }

    double minDist = double.infinity;
    for (int i = 0; i < polilinea.length - 1; i++) {
      final distSegmento =
          _distanciaPuntoASegmento(punto, polilinea[i], polilinea[i + 1]);
      if (distSegmento < minDist) {
        minDist = distSegmento;
      }
    }
    return minDist;
  }

  double _distanciaPuntoASegmento(LatLng p, LatLng a, LatLng b) {
    final dAB = _distanciaHaversineMetros(a, b);
    if (dAB == 0) return _distanciaHaversineMetros(p, a);

    final dAP = _distanciaHaversineMetros(a, p);
    final dBP = _distanciaHaversineMetros(b, p);

    if (dAP * dAP >= dBP * dBP + dAB * dAB) return dBP;
    if (dBP * dBP >= dAP * dAP + dAB * dAB) return dAP;

    final s = (dAB + dAP + dBP) / 2.0;
    final areaSq = s * (s - dAB) * (s - dAP) * (s - dBP);
    if (areaSq <= 0) return 0.0;
    return (2.0 * math.sqrt(areaSq)) / dAB;
  }
}
