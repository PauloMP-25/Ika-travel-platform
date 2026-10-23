import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/tema.dart';
import '../models/itinerario_modelo.dart';
import '../models/navegacion_modelo.dart';
import '../models/trafico_modelo.dart';
import '../services/navegacion_service.dart';
import '../services/trafico_service.dart';

/// Pantalla inmersiva de navegación vehicular guiada giro a giro tipo Google Maps.
class PantallaNavegacionGuiada extends StatefulWidget {
  final RutaNavegacion rutaInicial;
  final List<PuntoItinerario>? paradasItinerario;
  final List<RutaNavegacion>? rutasAlternativas;

  const PantallaNavegacionGuiada({
    super.key,
    required this.rutaInicial,
    this.paradasItinerario,
    this.rutasAlternativas,
  });

  @override
  State<PantallaNavegacionGuiada> createState() =>
      _PantallaNavegacionGuiadaState();
}

class _PantallaNavegacionGuiadaState extends State<PantallaNavegacionGuiada>
    with WidgetsBindingObserver {
  final _navService = NavegacionService();
  final _trafico = TraficoService();
  final _mapController = MapController();

  bool _seguirVehiculo = true;
  bool _orientacionRumboArriba = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarNavegacion();
    _navService.posicionActualNotifier.addListener(_alActualizarPosicion);
    _navService.paradaAlcanzadaNotifier.addListener(_alAlcanzarParada);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _navService.reintentarConexionGps();
    }
  }

  void _iniciarNavegacion() {
    _navService.iniciarNavegacion(
      ruta: widget.rutaInicial,
      paradasItinerario: widget.paradasItinerario,
      rutasAlternativas: widget.rutasAlternativas,
    );
    _trafico.obtenerIncidentes();
  }

  void _alActualizarPosicion() {
    final pos = _navService.posicionActualNotifier.value;
    if (pos == null || !mounted || !_seguirVehiculo) return;

    final rumbo = _orientacionRumboArriba
        ? _navService.rumboActualNotifier.value
        : 0.0;

    _mapController.moveAndRotate(pos, 17.0, rumbo);
  }

  void _alAlcanzarParada() {
    final parada = _navService.paradaAlcanzadaNotifier.value;
    if (parada == null || !mounted) return;

    final hayMas = _navService.hayMasDestinos;
    final idxActual = _navService.indiceParadaActualNotifier.value;
    final totalParadas = _navService.paradasItinerarioNotifier.value.length;
    final proxParada = hayMas
        ? _navService.paradasItinerarioNotifier.value[idxActual + 1]
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2E7D32),
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hayMas ? '¡Parada alcanzada!' : '¡Destino final alcanzado!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Has llegado a: ${parada.nombre}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (hayMas && proxParada != null) ...[
              Text(
                'Parada ${idxActual + 1} de $totalParadas completada.',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Siguiente destino: ${proxParada.nombre}',
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ] else ...[
              const Text(
                'Has completado todos los destinos programados de tu viaje.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (hayMas)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navService.detenerNavegacion();
                Navigator.pop(context);
              },
              child: const Text('Finalizar viaje'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hayMas
                  ? const Color(0xFF1565C0)
                  : const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (hayMas) {
                await _navService.avanzarASiguienteParada();
              } else {
                _navService.detenerNavegacion();
                Navigator.pop(context);
              }
            },
            child: Text(
              hayMas ? 'Continuar siguiente destino' : 'Finalizar viaje',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navService.posicionActualNotifier.removeListener(_alActualizarPosicion);
    _navService.paradaAlcanzadaNotifier.removeListener(_alAlcanzarParada);
    _navService.detenerNavegacion();
    super.dispose();
  }

  void _recentrar() {
    setState(() => _seguirVehiculo = true);
    final pos = _navService.posicionActualNotifier.value ??
        widget.rutaInicial.origen;
    final rumbo = _orientacionRumboArriba
        ? _navService.rumboActualNotifier.value
        : 0.0;
    _mapController.moveAndRotate(pos, 17.0, rumbo);
  }

  void _alternarOrientacion() {
    setState(() {
      _orientacionRumboArriba = !_orientacionRumboArriba;
    });
    final pos = _navService.posicionActualNotifier.value ??
        widget.rutaInicial.origen;
    final rumbo = _orientacionRumboArriba
        ? _navService.rumboActualNotifier.value
        : 0.0;
    _mapController.moveAndRotate(pos, 17.0, rumbo);
  }

  void _confirmarFinalizar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar navegación'),
        content: const Text('¿Deseas salir del modo de navegación guiada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar viaje'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context); // cerrar diálogo
              Navigator.pop(context); // salir de pantalla de navegación
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmarFinalizar();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ValueListenableBuilder<RutaNavegacion?>(
          valueListenable: _navService.rutaActivaNotifier,
          builder: (context, ruta, _) {
            final rutaActual = ruta ?? widget.rutaInicial;

            return Stack(
              children: [
                // 1. CAPA DE MAPA ──────────────────────────────────────────────
                _buildMapa(rutaActual),

                // 2. PANEL SUPERIOR DE MANIOBRA (ESTILO HUD AUTOMOTRIZ) ─────────
                _buildPanelSuperior(rutaActual),

                // 3. BANNER DE RECÁLCULO O ESTADO GPS ───────────────────────────
                _buildBannerEstado(),

                // 4. BOTONES FLOTANTES LATERALES ────────────────────────────────
                _buildBotonesFlotantes(),

                // 5. BARRA INFERIOR DE VIAJE Y METRICA ──────────────────────────
                _buildBarraInferior(rutaActual),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAPA
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMapa(RutaNavegacion ruta) {
    final centroInicial = ruta.origen;

    return ValueListenableBuilder<LatLng?>(
      valueListenable: _navService.posicionActualNotifier,
      builder: (context, posicionActual, _) {
        final posVehiculo = posicionActual ?? ruta.origen;

        return ValueListenableBuilder<double>(
          valueListenable: _navService.rumboActualNotifier,
          builder: (context, rumbo, _) {
            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: centroInicial,
                initialZoom: 16.5,
                onPositionChanged: (camara, gesture) {
                  // Si el usuario toca y arrastra el mapa manualmente, pausamos seguimiento
                  if (gesture) {
                    if (_seguirVehiculo) {
                      setState(() => _seguirVehiculo = false);
                    }
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ika.travel.mobile',
                ),

                // Trazo de polilíneas: rutas alternativas (gris atenuado) y activa (azul)
                ValueListenableBuilder<List<RutaNavegacion>>(
                  valueListenable: _navService.rutasAlternativasNotifier,
                  builder: (context, listaRutas, _) {
                    final polilineas = <Polyline>[];

                    // 1. Dibujar rutas alternativas no activas al fondo
                    for (final r in listaRutas) {
                      if (r.id != ruta.id) {
                        polilineas.add(
                          Polyline(
                            points: r.polilineaCompleta,
                            strokeWidth: 4.5,
                            color: const Color(0xFF78909C)
                                .withValues(alpha: 0.60),
                          ),
                        );
                      }
                    }

                    // 2. Dibujar la ruta seleccionada vigente encima con halo
                    polilineas.add(
                      Polyline(
                        points: ruta.polilineaCompleta,
                        strokeWidth: 8.0,
                        color: const Color(0xFF0D47A1)
                            .withValues(alpha: 0.35),
                      ),
                    );
                    polilineas.add(
                      Polyline(
                        points: ruta.polilineaCompleta,
                        strokeWidth: 5.5,
                        color: const Color(0xFF1976D2),
                      ),
                    );

                    return PolylineLayer(polylines: polilineas);
                  },
                ),

                // Marcadores: paradas del itinerario y vehículo
                ValueListenableBuilder<List<PuntoItinerario>>(
                  valueListenable: _navService.paradasItinerarioNotifier,
                  builder: (context, paradas, _) {
                    final idxActual =
                        _navService.indiceParadaActualNotifier.value;
                    final markers = <Marker>[];

                    // Paradas del itinerario
                    for (int i = 0; i < paradas.length; i++) {
                      final p = paradas[i];
                      final esCompletada = i < idxActual;
                      final esActual = i == idxActual;

                      Widget iconWidget;
                      Color pinColor;

                      if (esCompletada) {
                        pinColor = const Color(0xFF2E7D32); // Verde
                        iconWidget = const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        );
                      } else if (esActual) {
                        pinColor = const Color(0xFFD32F2F); // Rojo destino
                        iconWidget = const Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 20,
                        );
                      } else {
                        pinColor = const Color(0xFF1565C0); // Azul futura
                        iconWidget = Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }

                      markers.add(
                        Marker(
                          point: p.coordenadas,
                          width: 44,
                          height: 44,
                          child: Tooltip(
                            message: p.nombre,
                            child: Container(
                              decoration: BoxDecoration(
                                color: pinColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Center(child: iconWidget),
                            ),
                          ),
                        ),
                      );
                    }

                    // Marcador del vehículo (Chevron automotriz giratorio)
                    markers.add(
                      Marker(
                        point: posVehiculo,
                        width: 54,
                        height: 54,
                        child: Transform.rotate(
                          angle: (rumbo * math.pi / 180.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Halo de pulso
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF2196F3)
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              // Círculo base con flecha
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1565C0),
                                  border: Border.all(
                                      color: Colors.white, width: 3),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    return MarkerLayer(markers: markers);
                  },
                ),

                // Capa de marcadores de incidentes viales reales confirmados
                ValueListenableBuilder<List<IncidenteTrafico>>(
                  valueListenable: _trafico.incidentesNotifier,
                  builder: (context, incidentes, _) {
                    if (incidentes.isEmpty) return const SizedBox.shrink();

                    final incidentMarkers = incidentes.map((incidente) {
                      return Marker(
                        point: incidente.coordenadas,
                        width: 42,
                        height: 42,
                        child: GestureDetector(
                          onTap: () => _mostrarDetalleIncidenteModal(incidente),
                          child: Container(
                            decoration: BoxDecoration(
                              color: incidente.colorSeveridad,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              incidente.icono,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      );
                    }).toList();

                    return MarkerLayer(markers: incidentMarkers);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PANEL SUPERIOR DE MANIOBRA
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPanelSuperior(RutaNavegacion ruta) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<int>(
          valueListenable: _navService.pasoActualIndiceNotifier,
          builder: (context, indicePaso, _) {
            final pasoActual = (indicePaso < ruta.pasos.length)
                ? ruta.pasos[indicePaso]
                : (ruta.pasos.isNotEmpty ? ruta.pasos.last : null);

            final pasoSiguiente = (indicePaso + 1 < ruta.pasos.length)
                ? ruta.pasos[indicePaso + 1]
                : null;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2638), // Fondo azul noche oscuro
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de modo / precisión GPS superior
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder<EstadoGPS>(
                          valueListenable: _navService.estadoGpsNotifier,
                          builder: (context, estado, _) {
                            final esReal =
                                _navService.esUbicacionRealNotifier.value;
                            final colorDot = switch (estado) {
                              EstadoGPS.activo => (esReal
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFAB47BC)),
                              EstadoGPS.buscandoSenal =>
                                const Color(0xFFFFB300),
                              EstadoGPS.modoSimulacionPrueba =>
                                const Color(0xFF7E57C2),
                              _ => const Color(0xFFE53935),
                            };
                            final label = switch (estado) {
                              EstadoGPS.activo =>
                                (esReal ? 'GPS Real' : 'Simulación'),
                              EstadoGPS.buscandoSenal =>
                                'Buscando satélites…',
                              EstadoGPS.modoSimulacionPrueba => 'Modo Prueba',
                              _ => 'GPS Inactivo',
                            };
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorDot,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        ValueListenableBuilder<double>(
                          valueListenable: _navService.precisionMetrosNotifier,
                          builder: (context, prec, _) {
                            if (prec <= 0) return const SizedBox.shrink();
                            return Text(
                              '±${prec.round()}m',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),

                        // Chip de estado de tráfico en vivo
                        ValueListenableBuilder<EstadoProveedorTrafico>(
                          valueListenable: _trafico.estadoProveedorNotifier,
                          builder: (context, estadoTrafico, _) {
                            final (colorPill, iconoPill, textoPill) =
                                switch (estadoTrafico) {
                              EstadoProveedorTrafico.conectado => (
                                const Color(0xFFE65100),
                                Icons.traffic_rounded,
                                'Alertas viales',
                              ),
                              EstadoProveedorTrafico.sinIncidentes => (
                                const Color(0xFF4CAF50),
                                Icons.check_circle_outline_rounded,
                                'Vías despejadas',
                              ),
                              EstadoProveedorTrafico.cargando => (
                                const Color(0xFF29B6F6),
                                Icons.sync_rounded,
                                'Verificando…',
                              ),
                              EstadoProveedorTrafico.sinConfigurar => (
                                const Color(0xFF9E9E9E),
                                Icons.info_outline_rounded,
                                'Tráfico estándar',
                              ),
                              EstadoProveedorTrafico.cuotaExcedida => (
                                const Color(0xFFC2185B),
                                Icons.warning_amber_rounded,
                                'Cuota límite',
                              ),
                              EstadoProveedorTrafico.errorConexion => (
                                const Color(0xFFE53935),
                                Icons.cloud_off_rounded,
                                'Tráfico offline',
                              ),
                            };

                            return InkWell(
                              onTap: () => _mostrarEstadoTraficoDialog(context),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(iconoPill, color: colorPill, size: 12),
                                    const SizedBox(width: 5),
                                    Text(
                                      textoPill,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Ícono grande del giro
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32), // Verde giro
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            pasoSiguiente?.iconoManiobra ??
                                pasoActual?.iconoManiobra ??
                                Icons.navigation_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Distancia e instrucción
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ValueListenableBuilder<double>(
                                valueListenable: _navService
                                    .distanciaProximoGiroMetrosNotifier,
                                builder: (context, dist, _) {
                                  final distTxt = dist < 1000
                                      ? '${dist.round()} m'
                                      : '${(dist / 1000).toStringAsFixed(1)} km';

                                  return Text(
                                    dist > 0 ? 'En $distTxt' : 'Siga adelante',
                                    style: const TextStyle(
                                      color: Color(0xFF81C784),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 0.3,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pasoSiguiente?.instruccionEspanol ??
                                    pasoActual?.instruccionEspanol ??
                                    'Continúe por la ruta',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Maniobra siguiente secundaria (si existe)
                  if (indicePaso + 2 < ruta.pasos.length) ...[
                    const Divider(color: Colors.white12, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            ruta.pasos[indicePaso + 2].iconoManiobra,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Luego: ${ruta.pasos[indicePaso + 2].instruccionEspanol}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BANNER DE RECÁLCULO O ESTADO GPS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBannerEstado() {
    return Positioned(
      top: 155,
      left: 14,
      right: 14,
      child: Column(
        children: [
          // Banner de alerta de incidente confirmado en la ruta
          ValueListenableBuilder<IncidenteTrafico?>(
            valueListenable: _navService.alertaIncidenteActivoNotifier,
            builder: (context, incidente, _) {
              if (incidente == null) return const SizedBox.shrink();

              final esBloqueo = incidente.esBloqueoCompleto;
              final sugerida =
                  _navService.rutaAlternativaSugeridaNotifier.value;

              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: esBloqueo
                      ? const Color(0xFFC62828)
                      : const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(incidente.icono, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${incidente.nombreTipoEspanol.toUpperCase()} REPORTADO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 18),
                          onPressed: () =>
                              _navService.descartarAlertaIncidente(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'En ${incidente.viaAfectada}: ${incidente.descripcion}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sugerida != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: esBloqueo
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFFE65100),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.alt_route_rounded, size: 16),
                            label: Text(
                              'Desviar por ${sugerida.etiqueta}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () =>
                                _navService.desviarPorRutaAlternativa(),
                          ),
                        ],
                      ),
                    ] else if (esBloqueo) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFC62828),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.alt_route_rounded, size: 16),
                              label: const Text(
                                'Buscar y desviar por vía alterna',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () async {
                                final exito = await _navService.buscarYDesviarPorCallesAlternas();
                                if (!exito && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text('Buscando desvíos despejados por vías alternas...'),
                                          ),
                                        ],
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // Banner de recálculo activo
          ValueListenableBuilder<bool>(
            valueListenable: _navService.recalculandoRutaNotifier,
            builder: (context, recalculando, _) {
              if (!recalculando) return const SizedBox.shrink();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF57C00), // Naranja alerta
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Recalculando ruta…',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Banner de estado GPS (avisos de permisos o modo prueba)
          ValueListenableBuilder<EstadoGPS>(
            valueListenable: _navService.estadoGpsNotifier,
            builder: (context, estado, _) {
              if (estado == EstadoGPS.activo) return const SizedBox.shrink();

              String mensaje;
              Color colorFondo;
              Widget? accion;

              switch (estado) {
                case EstadoGPS.permisoDenegado:
                case EstadoGPS.permisoDenegadoPermanente:
                  mensaje =
                      'Permiso de ubicación denegado. Se requiere GPS para navegar.';
                  colorFondo = const Color(0xFFD32F2F);
                  accion = TextButton(
                    onPressed: () => Geolocator.openAppSettings(),
                    child: const Text('AJUSTES',
                        style: TextStyle(color: Colors.white)),
                  );
                  break;
                case EstadoGPS.desactivado:
                  mensaje = 'GPS apagado. Active la ubicación en su equipo.';
                  colorFondo = const Color(0xFFD32F2F);
                  accion = TextButton(
                    onPressed: () => Geolocator.openLocationSettings(),
                    child: const Text('ACTIVAR',
                        style: TextStyle(color: Colors.white)),
                  );
                  break;
                case EstadoGPS.buscandoSenal:
                  mensaje = 'Conectando con señal satelital GPS…';
                  colorFondo = const Color(0xFF0288D1);
                  accion = IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                    tooltip: 'Reintentar GPS',
                    onPressed: () => _navService.reintentarConexionGps(),
                  );
                  break;
                case EstadoGPS.modoSimulacionPrueba:
                  mensaje = 'Simulación de recorrido virtual en pantalla';
                  colorFondo = const Color(0xFF5E35B1);
                  break;
                case EstadoGPS.errorConexion:
                  mensaje = 'Problema de conexión con el sensor de ubicación.';
                  colorFondo = const Color(0xFFE65100);
                  accion = IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                    tooltip: 'Reintentar',
                    onPressed: () => _navService.reintentarConexionGps(),
                  );
                  break;
                default:
                  return const SizedBox.shrink();
              }

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colorFondo,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mensaje,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                    ?accion,
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SELECTOR MODAL DE RUTAS ALTERNATIVAS
  // ─────────────────────────────────────────────────────────────────────────

  void _mostrarSelectorRutasAlternativas() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ValueListenableBuilder<List<RutaNavegacion>>(
          valueListenable: _navService.rutasAlternativasNotifier,
          builder: (context, alternativas, _) {
            final rutaActual = _navService.rutaActivaNotifier.value;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.alt_route_rounded,
                            color: Color(0xFF1976D2), size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Rutas disponibles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${alternativas.length} opciones',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...alternativas.map((r) {
                      final esActiva = r.id == rutaActual?.id;
                      final baseDuracion = alternativas.first.duracionTotalSegundos;
                      final difMin = (r.duracionTotalSegundos - baseDuracion) / 60.0;
                      final txtDif = r.id == alternativas.first.id
                          ? 'Más rápida'
                          : (difMin > 0
                              ? '+${difMin.round()} min'
                              : '${difMin.round()} min');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: esActiva
                              ? const Color(0xFFE3F2FD)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: esActiva
                                ? const Color(0xFF1976D2)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: esActiva
                                ? const Color(0xFF1976D2)
                                : Colors.grey[400],
                            foregroundColor: Colors.white,
                            child: Icon(
                              esActiva
                                  ? Icons.check_circle_rounded
                                  : Icons.directions_car_rounded,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                r.etiqueta,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: esActiva
                                      ? const Color(0xFF0D47A1)
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: esActiva
                                      ? const Color(0xFFBBDEFB)
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  txtDif,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: esActiva
                                        ? const Color(0xFF0D47A1)
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${r.duracionTotalFormateada} • ${r.distanciaTotalFormateada}${r.resumenVia != null ? " • ${r.resumenVia}" : ""}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: esActiva
                              ? const Chip(
                                  label: Text(
                                    'En uso',
                                    style: TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: Color(0xFFBBDEFB),
                                  padding: EdgeInsets.zero,
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1976D2),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                  ),
                                  onPressed: () {
                                    _navService.seleccionarRutaAlternativa(r);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Elegir'),
                                ),
                          onTap: () {
                            if (!esActiva) {
                              _navService.seleccionarRutaAlternativa(r);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTONES FLOTANTES LATERALES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBotonesFlotantes() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      right: 16,
      bottom: 175 + bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón selector de rutas alternativas (solo visible si OSRM retornó más de 1 opción)
          ValueListenableBuilder<List<RutaNavegacion>>(
            valueListenable: _navService.rutasAlternativasNotifier,
            builder: (context, alternativas, _) {
              if (alternativas.length <= 1) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BotonFlotanteRedondo(
                  icono: Icons.alt_route_rounded,
                  tooltip: 'Comparar rutas alternativas (${alternativas.length})',
                  activo: true,
                  colorIcono: const Color(0xFF1565C0),
                  onPressed: _mostrarSelectorRutasAlternativas,
                ),
              );
            },
          ),

          // Botón orientación (Norte arriba vs Rumbo arriba)
          _BotonFlotanteRedondo(
            icono: _orientacionRumboArriba
                ? Icons.explore_rounded
                : Icons.navigation_outlined,
            tooltip: _orientacionRumboArriba
                ? 'Orientado al rumbo'
                : 'Orientado al norte',
            activo: _orientacionRumboArriba,
            onPressed: _alternarOrientacion,
          ),
          const SizedBox(height: 12),

          // Botón de silenciar / activar voz TTS
          ValueListenableBuilder<bool>(
            valueListenable: _navService.vozSilenciadaNotifier,
            builder: (context, silenciado, _) {
              return _BotonFlotanteRedondo(
                icono: silenciado
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                tooltip: silenciado ? 'Activar voz' : 'Silenciar voz',
                activo: !silenciado,
                onPressed: _navService.alternarSilencioVoz,
              );
            },
          ),
          const SizedBox(height: 12),

          // Botón de modo simulación (útil para pruebas en Chrome/PC)
          _BotonFlotanteRedondo(
            icono: Icons.play_arrow_rounded,
            tooltip: 'Iniciar recorrido virtual',
            activo: false,
            onPressed: () {
              final ruta =
                  _navService.rutaActivaNotifier.value ?? widget.rutaInicial;
              _navService.iniciarNavegacion(
                ruta: ruta,
                paradasItinerario: widget.paradasItinerario,
                rutasAlternativas: widget.rutasAlternativas,
                usarSimulacionPrueba: true,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Iniciando recorrido virtual en pantalla'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          // Botón de recentrar cámara (solo visible si el usuario movió el mapa)
          if (!_seguirVehiculo) ...[
            const SizedBox(height: 12),
            _BotonFlotanteRedondo(
              icono: Icons.my_location_rounded,
              tooltip: 'Recentrar en vehículo',
              activo: true,
              colorIcono: AppColores.naranjaBoton,
              onPressed: _recentrar,
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BARRA INFERIOR DE VIAJE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBarraInferior(RutaNavegacion ruta) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Tiempo restante y métricas de viaje
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Duración restante de conducción
                        ValueListenableBuilder<double>(
                          valueListenable:
                              _navService.tiempoRestanteTotalSegundosNotifier,
                          builder: (context, segundos, _) {
                            final min = (segundos / 60.0).round();
                            final txt = min < 60
                                ? '$min min'
                                : '${min ~/ 60} h ${min % 60} min';

                            return Text(
                              segundos > 0
                                  ? txt
                                  : ruta.duracionTotalFormateada,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2E7D32), // Verde llegada
                              ),
                            );
                          },
                        ),
                        // Velocidad instantánea
                        ValueListenableBuilder<double>(
                          valueListenable:
                              _navService.velocidadKmhNotifier,
                          builder: (context, vel, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColores.arenaFondo,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${vel.round()} km/h',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColores.marronOscuro,
                                ),
                              ),
                            );
                          },
                        ),
                        // Selector rápido de rutas si hay alternativas
                        ValueListenableBuilder<List<RutaNavegacion>>(
                          valueListenable: _navService.rutasAlternativasNotifier,
                          builder: (context, alts, _) {
                            if (alts.length <= 1) return const SizedBox.shrink();
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _mostrarSelectorRutasAlternativas,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.alt_route,
                                        size: 14, color: Color(0xFF1976D2)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${alts.length} rutas',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1976D2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Distancia restante y nombre de destino / parada
                    Row(
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable:
                              _navService.distanciaRestanteTotalMetrosNotifier,
                          builder: (context, metros, _) {
                            final distTxt = metros < 1000
                                ? '${metros.round()} m'
                                : '${(metros / 1000).toStringAsFixed(1)} km';
                            return Text(
                              metros > 0
                                  ? distTxt
                                  : ruta.distanciaTotalFormateada,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColores.grisTexto,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        const Text(' • ',
                            style: TextStyle(color: AppColores.grisTexto)),
                        Expanded(
                          child: ValueListenableBuilder<int>(
                            valueListenable:
                                _navService.indiceParadaActualNotifier,
                            builder: (context, idx, _) {
                              final paradas =
                                  _navService.paradasItinerarioNotifier.value;
                              final paradaActual = _navService.paradaActual;
                              final nombreDest =
                                  paradaActual?.nombre ?? ruta.nombreDestino;
                              final total = paradas.length;
                              final prefijo =
                                  total > 1 ? 'Parada ${idx + 1}/$total: ' : '';

                              return Text(
                                '$prefijo$nombreDest',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColores.marronOscuro,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    // Métricas complementarias: Tiempo transcurrido vs ETA de llegada aproximada (sin overflow)
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Tiempo real transcurrido
                        ValueListenableBuilder<int>(
                          valueListenable:
                              _navService.tiempoTranscurridoSegundosNotifier,
                          builder: (context, segundos, _) {
                            final m = segundos ~/ 60;
                            final s = segundos % 60;
                            final txt = m == 0
                                ? '$s s'
                                : (m < 60
                                    ? '$m min'
                                    : '${m ~/ 60}h ${m % 60}m');
                            return Text(
                              'En viaje: $txt',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColores.grisTexto,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),

                        // Hora estimada de llegada (ETA)
                        ValueListenableBuilder<String>(
                          valueListenable:
                              _navService.horaEstimadaLlegadaNotifier,
                          builder: (context, hora, _) {
                            if (hora.isEmpty) return const SizedBox.shrink();
                            return Text(
                              '• Llegada: $hora',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),
              // Botón Finalizar Viaje adaptado
              ElevatedButton.icon(
                onPressed: _confirmarFinalizar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text(
                  'Finalizar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODALES INFORMATIVOS DE TRÁFICO E INCIDENTES
  // ─────────────────────────────────────────────────────────────────────────

  void _mostrarDetalleIncidenteModal(IncidenteTrafico incidente) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: incidente.colorSeveridad.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        incidente.icono,
                        color: incidente.colorSeveridad,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            incidente.nombreTipoEspanol,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            incidente.viaAfectada,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: incidente.colorSeveridad,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        incidente.nombreSeveridadEspanol,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),
                Text(
                  incidente.descripcion,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                if (incidente.demoraSegundos > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Demora estimada: ${(incidente.demoraSegundos / 60).round()} min',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        size: 16, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Text(
                      'Fuente: ${incidente.proveedorFuente}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2638),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Entendido'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarEstadoTraficoDialog(BuildContext context) {
    final estado = _trafico.estadoProveedorNotifier.value;
    final mensaje = _trafico.mensajeEstadoNotifier.value;
    final tieneKey = _trafico.tieneCredenciales;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.traffic_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 10),
            Text('Tráfico e Incidentes', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado del servicio: ${estado.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(mensaje, style: TextStyle(color: Colors.grey[800])),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tieneKey
                          ? 'Monitoreo vial en vivo activo para la región Ica y corredores turísticos.'
                          : 'Alertas viales locales activas para tu trayecto.',
                      style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF1B5E20), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (tieneKey)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _trafico.obtenerIncidentes(forzarRecarga: true);
              },
              child: const Text('ACTUALIZAR AHORA'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2638),
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _BotonFlotanteRedondo extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final bool activo;
  final Color? colorIcono;
  final VoidCallback onPressed;

  const _BotonFlotanteRedondo({
    required this.icono,
    required this.tooltip,
    required this.activo,
    this.colorIcono,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.95),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icono,
              size: 24,
              color: colorIcono ??
                  (activo ? const Color(0xFF1976D2) : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
