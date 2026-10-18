import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/tema.dart';
import '../services/attractions_service.dart';
import 'pantalla_detalle.dart';
import 'pantalla_mas.dart';

class PantallaMapa extends StatefulWidget {
  final AttractionsService? attractionsService;

  const PantallaMapa({super.key, this.attractionsService});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  late final AttractionsService _attractionsService;
  List<Map<String, dynamic>> _ubicaciones = [];
  bool _cargando = true;

  final MapController _mapController = MapController();
  final LatLng _centroIca = const LatLng(-14.0678, -75.7286);
  double _zoomActual = 9.0;
  Map<String, dynamic>? _ubicacionSeleccionada;

  // Semilla de respaldo
  final List<Map<String, dynamic>> _ubicacionesSemilla = [
    {
      'id': '1',
      'titulo': 'Sandboarding en Huacachina',
      'subtitulo': 'Ica',
      'lat': -14.0875,
      'lng': -75.7628,
      'condicion': 'Excelente',
      'categoria': 'Aventura',
      'imagen': 'assets/images/detalle_sandboarding_1.jpg',
      'imagenes_detalle': ['assets/images/detalle_sandboarding_1.jpg'],
    },
    {
      'id': '2',
      'titulo': 'Islas Ballestas',
      'subtitulo': 'Paracas',
      'lat': -13.8333,
      'lng': -76.2500,
      'condicion': 'Excelente',
      'categoria': 'Naturaleza',
      'imagen': 'assets/images/act_ballestas1.jpg',
      'imagenes_detalle': ['assets/images/act_ballestas1.jpg'],
    },
    {
      'id': '3',
      'titulo': 'Reserva Nacional de Paracas',
      'subtitulo': 'Paracas',
      'lat': -13.8833,
      'lng': -76.2667,
      'condicion': 'Bueno',
      'categoria': 'Naturaleza',
      'imagen': 'assets/images/act_reserva1.jpg',
      'imagenes_detalle': ['assets/images/act_reserva1.jpg'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _attractionsService = widget.attractionsService ?? AttractionsService();
    _cargarAtractivosMapa();
  }

  Future<void> _cargarAtractivosMapa() async {
    setState(() => _cargando = true);
    try {
      final items = await _attractionsService.getAttractions(pageSize: 30);
      if (items.isNotEmpty) {
        // Obtenemos coordenadas para los primeros atractivos en paralelo
        final detalles = await Future.wait(
          items.take(10).map((att) async {
            try {
              final det = await _attractionsService.getAttractionDetail(att.id);
              return {
                'id': det.id,
                'titulo': det.name,
                'subtitulo': det.district,
                'lat': det.latitude != 0.0 ? det.latitude : -14.0678,
                'lng': det.longitude != 0.0 ? det.longitude : -75.7286,
                'condicion': 'Favorable',
                'categoria': det.categories.isNotEmpty ? det.categories.first : 'Turismo',
                'imagen': det.images.isNotEmpty ? det.images.first : (att.coverImageUrl ?? 'assets/images/carrusel_1_huacachina.jpg'),
                'imagenes_detalle': det.images.isNotEmpty ? det.images : [att.coverImageUrl ?? 'assets/images/carrusel_1_huacachina.jpg'],
              };
            } catch (_) {
              return att.toMap();
            }
          }),
        );

        if (mounted) {
          setState(() {
            _ubicaciones = detalles;
            _cargando = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('[PantallaMapa] Fallo al cargar del backend: $e');
    }

    if (mounted) {
      setState(() {
        _ubicaciones = _ubicacionesSemilla;
        _cargando = false;
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomActual = (_zoomActual + 1).clamp(3.0, 18.0);
      _mapController.move(_mapController.camera.center, _zoomActual);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomActual = (_zoomActual - 1).clamp(3.0, 18.0);
      _mapController.move(_mapController.camera.center, _zoomActual);
    });
  }

  void _centrarMapa() {
    setState(() {
      _zoomActual = 9.0;
      _mapController.move(_centroIca, _zoomActual);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroIca,
              initialZoom: _zoomActual,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (_, __) {
                if (_ubicacionSeleccionada != null) {
                  setState(() => _ubicacionSeleccionada = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ikatravel.app',
              ),
              MarkerLayer(
                markers: _ubicaciones.map((ubicacion) {
                  final isSelected = _ubicacionSeleccionada?['titulo'] == ubicacion['titulo'];
                  final lat = (ubicacion['lat'] as num?)?.toDouble() ?? _centroIca.latitude;
                  final lng = (ubicacion['lng'] as num?)?.toDouble() ?? _centroIca.longitude;

                  return Marker(
                    point: LatLng(lat, lng),
                    width: isSelected ? 55 : 45,
                    height: isSelected ? 55 : 45,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _ubicacionSeleccionada = ubicacion;
                        });
                        _mapController.move(LatLng(lat, lng), 12.0);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.red : AppColores.naranjaBoton,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          isSelected ? Icons.location_on : Icons.place,
                          color: Colors.white,
                          size: isSelected ? 30 : 24,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map, size: 18, color: AppColores.naranjaBoton),
                        const SizedBox(width: 8),
                        Text(
                          '${_ubicaciones.length} Atractivos en Ica',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.menu, color: AppColores.marronOscuro),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PantallaMas()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Controles de zoom
          Positioned(
            right: 16,
            bottom: _ubicacionSeleccionada != null ? 180 : 30,
            child: Column(
              children: [
                _botonControl(icon: Icons.add, onPressed: _zoomIn),
                const SizedBox(height: 8),
                _botonControl(icon: Icons.remove, onPressed: _zoomOut),
                const SizedBox(height: 8),
                _botonControl(icon: Icons.my_location, onPressed: _centrarMapa),
              ],
            ),
          ),

          // Card flotante al seleccionar marcador
          if (_ubicacionSeleccionada != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: GestureDetector(
                onTap: () {
                  final imagenes = (_ubicacionSeleccionada!['imagenes_detalle'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [_ubicacionSeleccionada!['imagen'].toString()];

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PantallaDetalle(
                        titulo: _ubicacionSeleccionada!['titulo'] ?? 'Atractivo',
                        subtitulo: _ubicacionSeleccionada!['subtitulo'] ?? 'Ica',
                        imagenes: imagenes,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _ubicacionSeleccionada!['imagen'].toString().startsWith('http')
                            ? Image.network(
                                _ubicacionSeleccionada!['imagen'],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                              )
                            : Image.asset(
                                _ubicacionSeleccionada!['imagen'],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ubicacionSeleccionada!['titulo'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _ubicacionSeleccionada!['subtitulo'],
                              style: const TextStyle(color: AppColores.grisTexto, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _ubicacionSeleccionada!['categoria'] ?? 'Turismo',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColores.naranjaBoton),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: AppColores.grisTexto),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _botonControl({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColores.marronOscuro, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}
