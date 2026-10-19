import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/tema.dart';
import '../models/itinerario_modelo.dart';
import '../services/itinerario_service.dart';

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
          ],
        ),
      ),
    );
  }

  Widget _buildMapa(ItinerarioViaje? it) {
    final centro = it?.origen?.coordenadas ?? const LatLng(-14.0685, -75.7288);
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

  const _PanelInferior({
    required this.it,
    required this.onAgregarDestino,
    required this.onCambiarOrigen,
    required this.onEliminarDestino,
    required this.onReordenar,
    required this.onCalcularRutas,
  });

  @override
  State<_PanelInferior> createState() => _PanelInferiorState();
}

class _PanelInferiorState extends State<_PanelInferior> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.it;
    final alturaMin = _expandido ? 380.0 : 160.0;

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
              padding: const EdgeInsets.symmetric(vertical: 10),
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

          // Resumen compacto (siempre visible)
          _ResumenItinerario(it: it, onExpandir: () {
            setState(() => _expandido = !_expandido);
          }),

          if (_expandido) ...[
            const Divider(height: 1),
            Expanded(child: _ListaDestinos(
              it: it,
              onCambiarOrigen: widget.onCambiarOrigen,
              onAgregarDestino: widget.onAgregarDestino,
              onEliminarDestino: widget.onEliminarDestino,
              onReordenar: widget.onReordenar,
              onCalcularRutas: widget.onCalcularRutas,
            )),
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
                  const SizedBox(width: 10),
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
  final VoidCallback onExpandir;

  const _ResumenItinerario({required this.it, required this.onExpandir});

  @override
  Widget build(BuildContext context) {
    final tieneRutas = it?.tieneRutas ?? false;
    final haySimulados = it?.tieneAlgunSimulado ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Estadísticas
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.route,
                        size: 16, color: AppColores.naranjaBoton),
                    const SizedBox(width: 6),
                    Text(
                      it != null
                          ? '${it!.destinos.length} destino${it!.destinos.length != 1 ? 's' : ''}'
                          : 'Sin destinos',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ],
                ),
                if (tieneRutas) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ChipResumen(
                        icon: Icons.straighten,
                        texto: it!.distanciaTotalFormateada,
                        color: AppColores.naranjaBoton,
                      ),
                      const SizedBox(width: 8),
                      _ChipResumen(
                        icon: Icons.access_time,
                        texto: it!.duracionTotalFormateada,
                        color: AppColores.marronOscuro,
                      ),
                      if (haySimulados) ...[
                        const SizedBox(width: 8),
                        _ChipResumen(
                          icon: Icons.warning_amber_rounded,
                          texto: 'Parcial simulado',
                          color: const Color(0xFFE65100),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
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

class _ListaDestinos extends StatelessWidget {
  final ItinerarioViaje? it;
  final VoidCallback onCambiarOrigen;
  final VoidCallback onAgregarDestino;
  final Function(String, String) onEliminarDestino;
  final Function(int, int) onReordenar;
  final Future<void> Function() onCalcularRutas;

  const _ListaDestinos({
    required this.it,
    required this.onCambiarOrigen,
    required this.onAgregarDestino,
    required this.onEliminarDestino,
    required this.onReordenar,
    required this.onCalcularRutas,
  });

  @override
  Widget build(BuildContext context) {
    final destinos = it?.destinos ?? [];
    final tramos = it?.tramos ?? [];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              // Origen
              _ItemOrigen(
                origen: it?.origen,
                onCambiar: onCambiarOrigen,
              ),
              // Destinos reordenables
              if (destinos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Agrega al menos un destino para crear tu ruta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColores.grisTexto, fontSize: 13),
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: destinos.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      onReordenar(oldIndex, newIndex),
                  itemBuilder: (ctx, i) {
                    final destino = destinos[i];
                    final tramo =
                        i < tramos.length ? tramos[i] : null;
                    return _ItemDestino(
                      key: ValueKey(destino.id),
                      destino: destino,
                      numero: i + 1,
                      tramo: tramo,
                      onEliminar: () {
                        onEliminarDestino(destino.id, destino.nombre);
                      },
                    );
                  },
                ),
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
                  onPressed: onAgregarDestino,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<EstadoCalculo>(
                  valueListenable:
                      ItinerarioService().estadoCalculoNotifier,
                  builder: (_, estado, __) {
                    final puede = it != null &&
                        (it!.puntos.length >= 2) &&
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
                      onPressed: puede ? onCalcularRutas : null,
                    );
                  },
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
                if (origen?.esUbicacionSimulada == true)
                  const Text(
                    '⚠ Ubicación simulada — GPS no disponible',
                    style: TextStyle(fontSize: 10, color: Color(0xFFE65100)),
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
  final TramoRuta? tramo;
  final VoidCallback onEliminar;

  const _ItemDestino({
    super.key,
    required this.destino,
    required this.numero,
    required this.tramo,
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
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColores.marronOscuro,
                  ),
                ),
                if (tramo != null) ...[
                  const SizedBox(height: 2),
                  Row(
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
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time,
                          size: 11,
                          color: color.withValues(alpha: 0.8)),
                      const SizedBox(width: 3),
                      Text(
                        tramo!.duracionFormateada,
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600),
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
          ),
          // Drag handle (ReorderableListView lo maneja automáticamente)
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Color(0xFFBDBDBD)),
            onPressed: onEliminar,
            visualDensity: VisualDensity.compact,
            tooltip: 'Quitar destino',
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

class _SelectorOrigen extends StatelessWidget {
  final String? origenActualId;
  final Function(PuntoItinerario) onSeleccionar;

  const _SelectorOrigen({
    required this.origenActualId,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    // Opciones de origen: el predeterminado + los destinos predefinidos
    final opciones = [
      DestinosPredefinidos.origenPredeterminado,
      ...DestinosPredefinidos.lista,
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
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
            'Seleccionar origen',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColores.marronOscuro,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '⚠ GPS no disponible sin geolocator — elige un punto de partida',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFFE65100)),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: opciones.map((punto) {
                final esActual = punto.id == origenActualId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esActual
                        ? AppColores.naranjaBoton
                        : const Color(0xFFFFF3E0),
                    child: Icon(
                      punto.esUbicacionSimulada
                          ? Icons.location_disabled
                          : Icons.trip_origin,
                      color: esActual
                          ? Colors.white
                          : AppColores.naranjaBoton,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    punto.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColores.marronOscuro,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    punto.esUbicacionSimulada
                        ? '⚠ Simulado — coordenadas fijas'
                        : punto.descripcion,
                    style: TextStyle(
                      fontSize: 11,
                      color: punto.esUbicacionSimulada
                          ? const Color(0xFFE65100)
                          : AppColores.grisTexto,
                    ),
                  ),
                  trailing: esActual
                      ? const Icon(Icons.check,
                          color: AppColores.naranjaBoton, size: 18)
                      : null,
                  onTap: () => onSeleccionar(punto),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
