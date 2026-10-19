import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/tema.dart';
import '../models/attraction_model.dart';
import '../services/attractions_service.dart';
import 'pantalla_detalle.dart';
import 'pantalla_mas.dart';

class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  final AttractionsService _attractionsService = AttractionsService();

  final List<Map<String, dynamic>> _ubicacionesFallback = [
    {
      'id': '1',
      'titulo': 'Sandboarding en Huacachina',
      'subtitulo': 'Ica',
      'lat': -14.0875,
      'lng': -75.7628,
      'condicion': 'Excelente',
      'indice': '95/100',
      'categoria': 'Aventura',
      'imagen': 'assets/images/detalle_sandboarding_1.jpg',
      'imagenes_detalle': [
        'assets/images/detalle_sandboarding_1.jpg',
        'assets/images/detalle_sandboarding_2.jpg',
        'assets/images/detalle_sandboarding_3.jpg',
      ],
    },
    {
      'id': '2',
      'titulo': 'Islas Ballestas',
      'subtitulo': 'Paracas',
      'lat': -13.8333,
      'lng': -76.2500,
      'condicion': 'Excelente',
      'indice': '88/100',
      'categoria': 'Naturaleza',
      'imagen': 'assets/images/act_ballestas1.jpg',
      'imagenes_detalle': [
        'assets/images/act_ballestas1.jpg',
        'assets/images/detalle_ballestas_2.jpg',
        'assets/images/detalle_ballestas_3.jpg',
      ],
    },
    {
      'id': '3',
      'titulo': 'Reserva Nacional de Paracas',
      'subtitulo': 'Paracas',
      'lat': -13.8833,
      'lng': -76.2667,
      'condicion': 'Bueno',
      'indice': '75/100',
      'categoria': 'Naturaleza',
      'imagen': 'assets/images/act_reserva1.jpg',
      'imagenes_detalle': [
        'assets/images/act_reserva1.jpg',
        'assets/images/detalle_reserva_2.jpg',
        'assets/images/detalle_reserva_3.jpg',
      ],
    },
    {
      'id': '4',
      'titulo': 'Viñedos y Bodegas',
      'subtitulo': 'Ica',
      'lat': -14.0500,
      'lng': -75.7167,
      'condicion': 'Excelente',
      'indice': '90/100',
      'categoria': 'Cultura',
      'imagen': 'assets/images/act_vinas1.jpg',
      'imagenes_detalle': [
        'assets/images/act_vinas1.jpg',
        'assets/images/detalle_vinas_2.jpg',
        'assets/images/detalle_vinas_3.jpg',
      ],
    },
    {
      'id': '5',
      'titulo': 'Cañón de los Perdidos',
      'subtitulo': 'Ocucaje',
      'lat': -14.5667,
      'lng': -75.6833,
      'condicion': 'Regular',
      'indice': '60/100',
      'categoria': 'Aventura',
      'imagen': 'assets/images/act_canon1.jpg',
      'imagenes_detalle': [
        'assets/images/act_canon1.jpg',
        'assets/images/detalle_canon_2.jpg',
        'assets/images/detalle_canon_3.jpg',
      ],
    },
  ];

  List<Map<String, dynamic>> _ubicaciones = [];
  bool _cargando = true;
  String _filtroSeleccionado = 'Todos';
  Map<String, dynamic>? _seleccionada;

  final List<String> _filtros = [
    'Todos',
    'Aventura',
    'Naturaleza',
    'Cultura',
  ];

  @override
  void initState() {
    super.initState();
    _cargarAtractivos();
  }

  Future<void> _cargarAtractivos() async {
    setState(() => _cargando = true);
    try {
      final items = await _attractionsService.getAttractions(pageSize: 30);
      if (items.isNotEmpty) {
        final List<Map<String, dynamic>> cargados = [];
        for (var item in items) {
          // Coordenadas conocidas por distrito o centro de Ica
          double lat = -14.0678;
          double lng = -75.7286;
          final d = item.district.toLowerCase();
          final n = item.name.toLowerCase();

          if (n.contains('huacachina') || d.contains('huacachina')) {
            lat = -14.0875;
            lng = -75.7628;
          } else if (n.contains('ballestas')) {
            lat = -13.8333;
            lng = -76.2500;
          } else if (d.contains('paracas')) {
            lat = -13.8833;
            lng = -76.2667;
          } else if (d.contains('nazca')) {
            lat = -14.8333;
            lng = -74.9333;
          } else if (n.contains('perdidos') || d.contains('ocucaje')) {
            lat = -14.5667;
            lng = -75.6833;
          }

          cargados.add({
            'id': item.id,
            'titulo': item.name,
            'subtitulo': item.district,
            'lat': lat,
            'lng': lng,
            'condicion': 'Recomendado',
            'indice': '88/100',
            'categoria': item.categories.isNotEmpty ? item.categories.first : 'Cultura',
            'imagen': item.coverImageUrl ?? 'assets/images/carrusel_1_huacachina.jpg',
            'imagenes_detalle': [
              item.coverImageUrl ?? 'assets/images/carrusel_1_huacachina.jpg',
            ],
          });
        }
        setState(() {
          _ubicaciones = cargados;
          _cargando = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _ubicaciones = _ubicacionesFallback;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listaParaMostrar = _filtroSeleccionado == 'Todos'
        ? _ubicaciones
        : _ubicaciones
            .where((u) => u['categoria'] == _filtroSeleccionado)
            .toList();

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Barra superior
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mapa Turístico',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColores.marronOscuro,
                          size: 26,
                        ),
                        onPressed: _cargarAtractivos,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.menu,
                          color: AppColores.marronOscuro,
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PantallaMas(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filtros de categoría
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtros.length,
                itemBuilder: (context, index) {
                  final filtro = _filtros[index];
                  final bool seleccionado = _filtroSeleccionado == filtro;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _filtroSeleccionado = filtro;
                        _seleccionada = null;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: seleccionado
                            ? AppColores.naranjaBoton
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        filtro,
                        style: TextStyle(
                          color: seleccionado
                              ? Colors.white
                              : AppColores.marronOscuro,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Mapa interactivo
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(-14.0678, -75.7286),
                      initialZoom: 9.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.ika_travel_mobile',
                      ),
                      MarkerLayer(
                        markers: listaParaMostrar.map((ubicacion) {
                          return Marker(
                            point: LatLng(ubicacion['lat'], ubicacion['lng']),
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _seleccionada = ubicacion;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColores.naranjaBoton,
                                  size: 32,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  if (_cargando)
                    const Positioned(
                      top: 15,
                      right: 15,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColores.naranjaBoton,
                        ),
                      ),
                    ),

                  // Tarjeta inferior flotante al seleccionar un punto
                  if (_seleccionada != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaDetalle(
                                titulo: _seleccionada!['titulo'],
                                subtitulo: _seleccionada!['subtitulo'],
                                imagenes: List<String>.from(
                                  _seleccionada!['imagenes_detalle'],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _seleccionada!['imagen'].startsWith('http')
                                    ? Image.network(
                                        _seleccionada!['imagen'],
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image, color: Colors.grey),
                                        ),
                                      )
                                    : Image.asset(
                                        _seleccionada!['imagen'],
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image, color: Colors.grey),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _seleccionada!['titulo'].replaceAll('\n', ' '),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColores.marronOscuro,
                                      ),
                                    ),
                                    Text(
                                      _seleccionada!['subtitulo'],
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColores.grisTexto,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _seleccionada!['condicion'],
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _seleccionada!['indice'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColores.marronOscuro,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: AppColores.grisTexto,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
