import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/tema.dart';
import '../models/itinerario_modelo.dart';
import '../services/itinerario_service.dart';
import '../services/osrm_service.dart';
import 'pantalla_navegacion_guiada.dart';

/// Pantalla principal del planificador de viajes.
///
/// Muestra un mapa con los puntos del itinerario y tramos de colores distintos.
/// El panel inferior permite agregar/reordenar destinos y calcular rutas.
///
/// DATOS SIMULADOS IDENTIFICADOS:
/// • Origen: se usa el centro de Ica como ubicación de inicio (GPS no disponible
///   sin el paquete geolocator; requiere Developer Mode en Windows para instalar).
/// • Rutas OSRM: referencial, sujeto a disponibilidad del servidor demo público.
///   Cuando OSRM falla, se calcula una línea recta con factor de ajuste ×1.3.
/// • Tiempos: basados en velocidad media de 60 km/h en carretera.
class PantallaPlaner extends StatefulWidget {
  const PantallaPlaner({super.key});

  @override
  State<PantallaPlaner> createState() => _PantallaPlanerState();
}

class _PantallaPlanerState extends State<PantallaPlaner>
    with TickerProviderStateMixin {
  final _itinerarioService = ItinerarioService();
  final _mapController = MapController();
  late final AnimationController _panelAnimController;

  @override
  void initState() {
    super.initState();
    _panelAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _itinerarioService.cargarItinerario();
  }

  @override
  void dispose() {
    _panelAnimController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────
  // Mapa
  // ─────────────────────────────────────────────────

  void _centrarMapa(ItinerarioViaje it) {
    if (it.puntos.isEmpty) return;
    if (it.puntos.length == 1) {
      _mapController.move(it.puntos.first.coordenadas, 12.0);
      return;
    }
    // Calcular bounds
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLon = double.infinity, maxLon = -double.infinity;
    for (final p in it.puntos) {
      if (p.coordenadas.latitude < minLat) minLat = p.coordenadas.latitude;
      if (p.coordenadas.latitude > maxLat) maxLat = p.coordenadas.latitude;
      if (p.coordenadas.longitude < minLon) minLon = p.coordenadas.longitude;
      if (p.coordenadas.longitude > maxLon) maxLon = p.coordenadas.longitude;
    }
    final bounds = LatLngBounds(
      LatLng(minLat, minLon),
      LatLng(maxLat, maxLon),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(50, 100, 50, 280),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // Acciones de usuario
  // ─────────────────────────────────────────────────

  void _abrirSelectorDestino() {
    final it = _itinerarioService.itinerario;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorDestino(
        destinosYaAgregados: it?.puntos.map((p) => p.id).toSet() ?? {},
        onSeleccionar: (punto) {
          _itinerarioService.agregarDestino(punto);
          Navigator.pop(context);
          // Centrar mapa con el nuevo punto
          final itActual = _itinerarioService.itinerario;
          if (itActual != null) _centrarMapa(itActual);
        },
      ),
    );
  }

  void _abrirSelectorOrigen() {
    final it = _itinerarioService.itinerario;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorOrigen(
        origenActualId: it?.origen?.id,
        onSeleccionar: (punto) {
          _itinerarioService.establecerOrigen(punto);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _calcularRutas() async {
    await _itinerarioService.calcularRutas();
    final it = _itinerarioService.itinerario;
    if (it != null && mounted) _centrarMapa(it);
  }

  void _confirmarEliminarDestino(String id, String nombre) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar destino'),
        content: Text('¿Quitar "$nombre" del itinerario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _itinerarioService.eliminarDestino(id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }

  Future<void> _iniciarNavegacionVehicular(
      {PuntoItinerario? destinoEspecifico}) async {
    final it = _itinerarioService.itinerario;
    if (it == null || it.puntos.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Agrega al menos un destino para iniciar navegación')),
      );
      return;
    }

    // 1. Validar si el servicio de ubicación (GPS) está encendido en el teléfono
    final gpsActivo = await Geolocator.isLocationServiceEnabled();
    if (!gpsActivo) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Color(0xFFD32F2F), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Activar GPS Requerido',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Para iniciar la navegación vehicular asistida por voz y seguimiento en vivo por las calles de Ica, activa la ubicación satelital (GPS).',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaBoton,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Abrir Ajustes GPS'),
              onPressed: () async {
                Navigator.pop(ctx);
                await Geolocator.openLocationSettings();
              },
            ),
          ],
        ),
      );
      return;
    }

    // 2. Verificar permisos de ubicación
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de GPS denegado. No se puede iniciar la navegación.'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
        return;
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Permiso GPS Denegado'),
          content: const Text('Habilita el permiso de ubicación en los ajustes para usar la navegación guiada.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Geolocator.openAppSettings();
              },
              child: const Text('Abrir Ajustes'),
            ),
          ],
        ),
      );
      return;
    }

    // 3. Determinar el punto de origen (utilizar GPS real si está disponible)
    LatLng origen = it.origen?.coordenadas ?? const LatLng(-14.0678, -75.7286);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
      origen = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // Si demora, se mantiene el origen definido en el itinerario
    }

    final paradas = destinoEspecifico != null
        ? [
            destinoEspecifico,
            ...it.destinos.where((d) => d.id != destinoEspecifico.id)
          ]
        : it.destinos;
    final destino = paradas.first;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Iniciando navegación GPS…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final rutas = await OsrmService().obtenerRutasConAlternativas(
        origen: origen,
        destino: destino.coordenadas,
        nombreDestino: destino.nombre,
        incluirAlternativas: true,
      );

      final ruta = rutas.first;

      if (mounted) {
        Navigator.pop(context); // cerrar diálogo
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaNavegacionGuiada(
              rutaInicial: ruta,
              paradasItinerario: paradas,
              rutasAlternativas: rutas,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar navegación: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: ValueListenableBuilder<ItinerarioViaje?>(
        valueListenable: _itinerarioService.itinerarioNotifier,
        builder: (context, it, _) {
          return Stack(
            children: [
              // ── Mapa ──────────────────────────────
              _buildMapa(it),
              // ── AppBar flotante ───────────────────
              _buildAppBar(it),
              // ── Panel inferior ────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PanelInferior(
                  it: it,
                  onAgregarDestino: _abrirSelectorDestino,
                  onCambiarOrigen: _abrirSelectorOrigen,
                  onEliminarDestino: _confirmarEliminarDestino,
                  onReordenar: _itinerarioService.reordenarDestinos,
                  onCalcularRutas: _calcularRutas,
                  onIniciarNavegacion: _iniciarNavegacionVehicular,
                ),
              ),
              // ── Overlay de cálculo ────────────────
              ValueListenableBuilder<EstadoCalculo>(
                valueListenable:
                    _itinerarioService.estadoCalculoNotifier,
                builder: (ctx, estado, _) {
                  if (estado != EstadoCalculo.calculando) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<String>(
                    valueListenable:
                        _itinerarioService.mensajeCalculoNotifier,
                    builder: (ctx, mensaje, _) =>
                        _OverlayCalculo(mensaje: mensaje),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(ItinerarioViaje? it) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Botón atrás
            _BotonesMapa(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            // Título editable
            Expanded(
              child: GestureDetector(
                onTap: _editarTitulo,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.route,
                          size: 18, color: AppColores.naranjaBoton),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          it?.titulo ?? 'Mi itinerario',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColores.marronOscuro,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.edit_outlined,
                          size: 16, color: AppColores.grisTexto),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón centrar
            _BotonesMapa(
              icon: Icons.center_focus_strong_outlined,
              onTap: () {
                if (it != null) _centrarMapa(it);
              },
            ),
            const SizedBox(width: 6),
            // Botón de ayuda e indicaciones de uso del planificador
            _BotonesMapa(
              icon: Icons.help_outline_rounded,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        child: _TarjetasIndicacionesUso(
                          onAgregarDestino: () {
                            Navigator.pop(ctx);
                            _abrirSelectorDestino();
                          },
                          esColapsable: true,
                          onCerrar: () => Navigator.pop(ctx),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapa(ItinerarioViaje? it) {
    final centro = it?.origen?.coordenadas ?? const LatLng(-14.0678, -75.7286);
    final polylines = <Polyline>[];
    final marcadores = <Marker>[];

    if (it != null) {
      // Polilíneas de tramos
      for (final tramo in it.tramos) {
        polylines.add(Polyline(
          points: tramo.polilinea,
          strokeWidth: tramo.esSimulado ? 2.5 : 4.0,
          color: tramo.color,
          pattern: tramo.esSimulado
              ? StrokePattern.dashed(segments: const [8, 6])
              : const StrokePattern.solid(),
        ));
      }

      // Marcadores de puntos
      for (int i = 0; i < it.puntos.length; i++) {
        final p = it.puntos[i];
        final esOrigen = i == 0;
        marcadores.add(
          Marker(
            point: p.coordenadas,
            width: 46,
            height: 54,
            child: _MarcadorMapa(
              etiqueta: esOrigen ? '●' : '$i',
              color: esOrigen
                  ? AppColores.naranjaBoton
                  : (it.tramos.isNotEmpty && i - 1 < it.tramos.length
                      ? it.tramos[i - 1].color
                      : AppColores.marronOscuro),
              esOrigen: esOrigen,
              nombre: p.nombre,
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: centro,
        initialZoom: 10.0,
        onTap: (_, __) {},
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ika.travel.mobile',
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (marcadores.isNotEmpty) MarkerLayer(markers: marcadores),
      ],
    );
  }

  void _editarTitulo() {
    final controller = TextEditingController(
      text: _itinerarioService.itinerario?.titulo ?? '',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar itinerario'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre del itinerario'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _itinerarioService.cambiarTitulo(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel inferior
// ─────────────────────────────────────────────────────────────────────────────

class _PanelInferior extends StatefulWidget {
  final ItinerarioViaje? it;
  final VoidCallback onAgregarDestino;
  final VoidCallback onCambiarOrigen;
  final Function(String id, String nombre) onEliminarDestino;
  final Function(int antiguo, int nuevo) onReordenar;
  final Future<void> Function() onCalcularRutas;
  final VoidCallback onIniciarNavegacion;

  const _PanelInferior({
    required this.it,
    required this.onAgregarDestino,
    required this.onCambiarOrigen,
    required this.onEliminarDestino,
    required this.onReordenar,
    required this.onCalcularRutas,
    required this.onIniciarNavegacion,
  });

  @override
  State<_PanelInferior> createState() => _PanelInferiorState();
}

class _PanelInferiorState extends State<_PanelInferior> {
  late bool _expandido;

  @override
  void initState() {
    super.initState();
    // Expandido por defecto si ya existen destinos para verlos de inmediato
    _expandido = (widget.it?.destinos.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.it;
    final alturaMin = _expandido ? 430.0 : 160.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: alturaMin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle + toggle
          GestureDetector(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Resumen compacto (siempre visible con toggle y métricas de tour)
          _ResumenItinerario(
            it: it,
            expandido: _expandido,
            onExpandir: () {
              setState(() => _expandido = !_expandido);
            },
          ),

          if (_expandido) ...[
            const Divider(height: 1),
            Expanded(
              child: _ListaDestinos(
                it: it,
                onCambiarOrigen: widget.onCambiarOrigen,
                onAgregarDestino: widget.onAgregarDestino,
                onEliminarDestino: widget.onEliminarDestino,
                onReordenar: widget.onReordenar,
                onCalcularRutas: widget.onCalcularRutas,
                onIniciarNavegacion: widget.onIniciarNavegacion,
              ),
            ),
          ] else ...[
            const Spacer(),
            // Barra de acciones compacta
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_location_alt_outlined,
                          size: 18),
                      label: const Text('Agregar destino'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColores.naranjaBoton,
                        side:
                            const BorderSide(color: AppColores.naranjaBoton),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: widget.onAgregarDestino,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (it != null && it.tieneRutas)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text('Navegar GPS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: widget.onIniciarNavegacion,
                      ),
                    )
                  else
                    Expanded(
                      child: ValueListenableBuilder<EstadoCalculo>(
                        valueListenable:
                            ItinerarioService().estadoCalculoNotifier,
                        builder: (_, estado, __) {
                          final puedeCalcular = it != null &&
                              it.puntos.length >= 2 &&
                              estado != EstadoCalculo.calculando;
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('Calcular rutas'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: puedeCalcular
                                  ? AppColores.marronOscuro
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                puedeCalcular ? widget.onCalcularRutas : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resumen del itinerario
// ─────────────────────────────────────────────────────────────────────────────

class _ResumenItinerario extends StatelessWidget {
  final ItinerarioViaje? it;
  final bool expandido;
  final VoidCallback onExpandir;

  const _ResumenItinerario({
    required this.it,
    required this.expandido,
    required this.onExpandir,
  });

  @override
  Widget build(BuildContext context) {
    final tieneRutas = it?.tieneRutas ?? false;
    final haySimulados = it?.tieneAlgunSimulado ?? false;
    final numDestinos = it?.destinos.length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón interactivo para alternar lista de destinos
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onExpandir,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.route, size: 18, color: AppColores.naranjaBoton),
                      const SizedBox(width: 6),
                      Text(
                        it != null
                            ? '$numDestinos destino${numDestinos != 1 ? 's' : ''}'
                            : 'Sin destinos',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        expandido
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: AppColores.naranjaBoton,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Estado cálculo
              ValueListenableBuilder<EstadoCalculo>(
                valueListenable: ItinerarioService().estadoCalculoNotifier,
                builder: (_, estado, __) {
                  return _BadgeEstado(estado: estado);
                },
              ),
            ],
          ),

          if (tieneRutas) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _ChipResumen(
                  icon: Icons.straighten,
                  texto: it!.distanciaTotalFormateada,
                  color: AppColores.naranjaBoton,
                ),
                _ChipResumen(
                  icon: Icons.directions_car,
                  texto: 'Ruta: ${it!.duracionTotalFormateada}',
                  color: const Color(0xFF1565C0),
                ),
                _ChipResumen(
                  icon: Icons.access_time_filled,
                  texto: 'Visitas: ~${it!.tiempoEstadiaTotalFormateada}',
                  color: const Color(0xFF2E7D32),
                ),
                if (numDestinos > 1)
                  _ChipResumen(
                    icon: Icons.tour_rounded,
                    texto: 'Tour: ~${it!.tiempoTotalTourFormateado}',
                    color: AppColores.marronOscuro,
                  ),
                if (haySimulados)
                  const _ChipResumen(
                    icon: Icons.warning_amber_rounded,
                    texto: 'Parcial simulado',
                    color: Color(0xFFE65100),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipResumen extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color color;

  const _ChipResumen(
      {required this.icon, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(texto,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BadgeEstado extends StatelessWidget {
  final EstadoCalculo estado;
  const _BadgeEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    return switch (estado) {
      EstadoCalculo.completado => _badge(
          'OSRM ✓', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      EstadoCalculo.errorParcial => _badge(
          'Parcial', const Color(0xFFE65100), const Color(0xFFFFF3E0)),
      EstadoCalculo.calculando => _badge(
          'Calculando', AppColores.naranjaBoton,
          const Color(0xFFFFF8E1)),
      EstadoCalculo.inactivo => const SizedBox.shrink(),
    };
  }

  Widget _badge(String texto, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11, color: fg, fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lista de destinos reordenable
// ─────────────────────────────────────────────────────────────────────────────

class _ListaDestinos extends StatefulWidget {
  final ItinerarioViaje? it;
  final VoidCallback onCambiarOrigen;
  final VoidCallback onAgregarDestino;
  final Function(String, String) onEliminarDestino;
  final Function(int, int) onReordenar;
  final Future<void> Function() onCalcularRutas;
  final VoidCallback onIniciarNavegacion;

  const _ListaDestinos({
    required this.it,
    required this.onCambiarOrigen,
    required this.onAgregarDestino,
    required this.onEliminarDestino,
    required this.onReordenar,
    required this.onCalcularRutas,
    required this.onIniciarNavegacion,
  });

  @override
  State<_ListaDestinos> createState() => _ListaDestinosState();
}

class _ListaDestinosState extends State<_ListaDestinos> {
  @override
  Widget build(BuildContext context) {
    final destinos = widget.it?.destinos ?? [];
    final tramos = widget.it?.tramos ?? [];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              // Origen
              _ItemOrigen(
                origen: widget.it?.origen,
                onCambiar: widget.onCambiarOrigen,
              ),

              // Si no hay destinos, mostrar las tarjetas de indicaciones de uso directamente
              if (destinos.isEmpty) ...[
                _TarjetasIndicacionesUso(
                  onAgregarDestino: widget.onAgregarDestino,
                ),
              ] else ...[
                const SizedBox(height: 6),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: destinos.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    widget.onReordenar(oldIndex, newIndex);
                  },
                  itemBuilder: (ctx, i) {
                    final destino = destinos[i];
                    final tramo =
                        i < tramos.length ? tramos[i] : null;
                    return _ItemDestino(
                      key: ValueKey(destino.id),
                      destino: destino,
                      numero: i + 1,
                      totalDestinos: destinos.length,
                      tramo: tramo,
                      onMoverArriba: i > 0 ? () => widget.onReordenar(i, i - 1) : null,
                      onMoverAbajo:
                          i < destinos.length - 1 ? () => widget.onReordenar(i, i + 1) : null,
                      onEliminar: () {
                        widget.onEliminarDestino(destino.id, destino.nombre);
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        // Botones de acción
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined,
                      size: 16),
                  label: const Text('Agregar destino'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColores.naranjaBoton,
                    side: const BorderSide(color: AppColores.naranjaBoton),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: widget.onAgregarDestino,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.it != null && widget.it!.tieneRutas) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: const Text('Navegar GPS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: widget.onIniciarNavegacion,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ValueListenableBuilder<EstadoCalculo>(
                    valueListenable:
                        ItinerarioService().estadoCalculoNotifier,
                    builder: (_, estado, __) {
                      final puede = widget.it != null &&
                          (widget.it!.puntos.length >= 2) &&
                          estado != EstadoCalculo.calculando;
                      return ElevatedButton.icon(
                        icon: const Icon(Icons.directions, size: 16),
                        label: const Text('Calcular rutas'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              puede ? AppColores.marronOscuro : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: puede ? widget.onCalcularRutas : null,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjetas de indicaciones y pasos para usar el planificador de recorridos
class _TarjetasIndicacionesUso extends StatelessWidget {
  final VoidCallback onAgregarDestino;
  final bool esColapsable;
  final VoidCallback? onCerrar;

  const _TarjetasIndicacionesUso({
    required this.onAgregarDestino,
    this.esColapsable = false,
    this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEADBCE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColores.naranjaBoton.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map_rounded,
                    color: AppColores.naranjaBoton, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Guía rápida: ¿Cómo armar tu tour?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppColores.marronOscuro,
                  ),
                ),
              ),
              if (esColapsable && onCerrar != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColores.grisTexto),
                  onPressed: onCerrar,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _itemPaso(
            numero: '1',
            titulo: 'Agrega tus destinos',
            descripcion:
                'Toca "+ Agregar destino" y suma lugares clave de Ica (Huacachina, Luren, Tacama, Paracas...).',
            icono: Icons.add_location_alt_rounded,
            color: const Color(0xFFD97724),
          ),
          const SizedBox(height: 10),
          _itemPaso(
            numero: '2',
            titulo: 'Organiza el orden de paradas',
            descripcion:
                'Usa las flechas (↑ / ↓) en cada tarjeta para ordenar tu ruta y evitar vueltas innecesarias.',
            icono: Icons.swap_vert_rounded,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(height: 10),
          _itemPaso(
            numero: '3',
            titulo: 'Revisa tiempos de visita y tour',
            descripcion:
                'Cada parada incluye una sugerencia de estadía (~45m a 2h) para planear el tiempo total de tu día.',
            icono: Icons.timer_outlined,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(height: 10),
          _itemPaso(
            numero: '4',
            titulo: 'Inicia navegación GPS con voz',
            descripcion:
                'Presiona "Navegar GPS" para recibir guía paso a paso, alertas viales y desvíos inteligentes ante cierres.',
            icono: Icons.navigation_rounded,
            color: const Color(0xFF6A1B9A),
          ),
          if (!esColapsable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar mi primer destino'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.naranjaBoton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onAgregarDestino,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemPaso({
    required String numero,
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Icon(icono, size: 15, color: color),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paso $numero: $titulo',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: AppColores.marronOscuro,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                descripcion,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColores.grisTexto,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemOrigen extends StatelessWidget {
  final PuntoItinerario? origen;
  final VoidCallback onCambiar;

  const _ItemOrigen({required this.origen, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColores.naranjaBoton.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trip_origin,
              size: 20, color: AppColores.naranjaBoton),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  origen?.nombre ?? 'Sin origen',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColores.marronOscuro,
                  ),
                ),
                Text(
                  origen?.descripcion ?? 'Punto de partida del recorrido',
                  style: const TextStyle(fontSize: 11, color: AppColores.grisTexto),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCambiar,
            style: TextButton.styleFrom(
              foregroundColor: AppColores.naranjaBoton,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Cambiar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ItemDestino extends StatelessWidget {
  final PuntoItinerario destino;
  final int numero;
  final int totalDestinos;
  final TramoRuta? tramo;
  final VoidCallback? onMoverArriba;
  final VoidCallback? onMoverAbajo;
  final VoidCallback onEliminar;

  const _ItemDestino({
    super.key,
    required this.destino,
    required this.numero,
    required this.totalDestinos,
    required this.tramo,
    this.onMoverArriba,
    this.onMoverAbajo,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final color = tramo?.color ?? AppColores.marronOscuro;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Número / color tramo
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$numero',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destino.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColores.marronOscuro,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (destino.tiempoVisitaMinutos > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 11, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 3),
                          Text(
                            'Visita: ~${destino.tiempoVisitaFormateado}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (tramo != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.straighten,
                              size: 11,
                              color: color.withValues(alpha: 0.8)),
                          const SizedBox(width: 3),
                          Text(
                            tramo!.distanciaFormateada,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.directions_car,
                              size: 11,
                              color: color.withValues(alpha: 0.8)),
                          const SizedBox(width: 3),
                          Text(
                            tramo!.duracionFormateada,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (tramo!.esSimulado) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.warning_amber_rounded,
                                size: 11, color: Color(0xFFE65100)),
                            const Text(
                              'Sim.',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFFE65100)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Botones de reordenar y eliminar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (totalDestinos > 1) ...[
                if (onMoverArriba != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded,
                        size: 18, color: AppColores.marronOscuro),
                    tooltip: 'Subir orden',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onMoverArriba,
                  ),
                if (onMoverAbajo != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward_rounded,
                        size: 18, color: AppColores.marronOscuro),
                    tooltip: 'Bajar orden',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onMoverAbajo,
                  ),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFFE53935)),
                onPressed: onEliminar,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Quitar destino',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marcador del mapa
// ─────────────────────────────────────────────────────────────────────────────

class _MarcadorMapa extends StatelessWidget {
  final String etiqueta;
  final Color color;
  final bool esOrigen;
  final String nombre;

  const _MarcadorMapa({
    required this.etiqueta,
    required this.color,
    required this.esOrigen,
    required this.nombre,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: esOrigen ? 32 : 28,
          height: esOrigen ? 32 : 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: esOrigen
                ? const Icon(Icons.trip_origin, color: Colors.white, size: 16)
                : Text(
                    etiqueta,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        // Punta del pin
        CustomPaint(
          size: const Size(12, 6),
          painter: _PintorPunta(color: color),
        ),
      ],
    );
  }
}

class _PintorPunta extends CustomPainter {
  final Color color;
  const _PintorPunta({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay de cálculo
// ─────────────────────────────────────────────────────────────────────────────

class _OverlayCalculo extends StatelessWidget {
  final String mensaje;
  const _OverlayCalculo({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppColores.naranjaBoton),
              const SizedBox(height: 16),
              Text(
                mensaje,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColores.marronOscuro,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Consultando OSRM…\nUsando ruta simulada si no responde.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botones flotantes del mapa
// ─────────────────────────────────────────────────────────────────────────────

class _BotonesMapa extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _BotonesMapa({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColores.marronOscuro),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selector de destino (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _SelectorDestino extends StatelessWidget {
  final Set<String> destinosYaAgregados;
  final Function(PuntoItinerario) onSeleccionar;

  const _SelectorDestino({
    required this.destinosYaAgregados,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Agregar destino',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColores.marronOscuro,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona un punto turístico de Ica',
            style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: DestinosPredefinidos.lista.map((punto) {
                final yaAgregado = destinosYaAgregados.contains(punto.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: yaAgregado
                        ? Colors.grey[200]
                        : AppColores.naranjaBoton.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.place_outlined,
                      color: yaAgregado
                          ? Colors.grey
                          : AppColores.naranjaBoton,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    punto.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: yaAgregado
                          ? Colors.grey
                          : AppColores.marronOscuro,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    punto.descripcion,
                    style: const TextStyle(
                        fontSize: 11, color: AppColores.grisTexto),
                  ),
                  trailing: yaAgregado
                      ? const Icon(Icons.check,
                          color: AppColores.naranjaBoton, size: 18)
                      : null,
                  enabled: !yaAgregado,
                  onTap: yaAgregado ? null : () => onSeleccionar(punto),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selector de origen (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _SelectorOrigen extends StatefulWidget {
  final String? origenActualId;
  final Function(PuntoItinerario) onSeleccionar;

  const _SelectorOrigen({
    required this.origenActualId,
    required this.onSeleccionar,
  });

  @override
  State<_SelectorOrigen> createState() => _SelectorOrigenState();
}

class _SelectorOrigenState extends State<_SelectorOrigen> {
  bool _obteniendoGps = false;

  Future<void> _usarUbicacionGpsReal() async {
    setState(() => _obteniendoGps = true);
    try {
      final gpsActivo = await Geolocator.isLocationServiceEnabled();
      if (!gpsActivo) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Por favor activa el GPS de tu celular en Ajustes.'),
              action: SnackBarAction(
                label: 'Ajustes',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.whileInUse || permiso == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        final puntoGps = PuntoItinerario(
          id: 'origen_gps_real',
          nombre: 'Mi ubicación actual (GPS en vivo)',
          descripcion: 'Coordenadas reales: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
          coordenadas: LatLng(pos.latitude, pos.longitude),
          esUbicacionSimulada: false,
        );
        widget.onSeleccionar(puntoGps);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se requiere permiso de ubicación para usar tu GPS.')),
        );
      }
    } catch (e) {
      debugPrint('[SelectorOrigen] Error al obtener GPS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la posición GPS actual. Intenta nuevamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Opciones de origen: el predeterminado + los destinos predefinidos
    final opciones = [
      DestinosPredefinidos.origenPredeterminado,
      ...DestinosPredefinidos.lista,
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Seleccionar punto de origen',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColores.marronOscuro,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Elige tu punto de partida o usa tu ubicación GPS en vivo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // OPCIÓN DESTACADA: GPS REAL EN VIVO
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE3F2FD),
              child: _obteniendoGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1976D2)),
                    )
                  : const Icon(Icons.my_location, color: Color(0xFF1976D2), size: 20),
            ),
            title: const Text(
              'Mi ubicación actual (GPS en tiempo real)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
                fontSize: 14,
              ),
            ),
            subtitle: const Text(
              'Usar coordenadas satelitales en vivo de tu teléfono',
              style: TextStyle(fontSize: 11, color: AppColores.grisTexto),
            ),
            trailing: widget.origenActualId == 'origen_gps_real'
                ? const Icon(Icons.check_circle, color: Color(0xFF1976D2), size: 20)
                : const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            onTap: _obteniendoGps ? null : _usarUbicacionGpsReal,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: opciones.map((punto) {
                final esActual = punto.id == widget.origenActualId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esActual
                        ? AppColores.naranjaBoton
                        : const Color(0xFFFFF3E0),
                    child: Icon(
                      Icons.trip_origin,
                      color: esActual
                          ? Colors.white
                          : AppColores.naranjaBoton,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    punto.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColores.marronOscuro,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    punto.descripcion,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColores.grisTexto,
                    ),
                  ),
                  trailing: esActual
                      ? const Icon(Icons.check,
                          color: AppColores.naranjaBoton, size: 18)
                      : null,
                  onTap: () => widget.onSeleccionar(punto),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
