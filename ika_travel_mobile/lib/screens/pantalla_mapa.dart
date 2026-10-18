import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/tema.dart';
import 'pantalla_detalle.dart';
import 'pantalla_mas.dart';

class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  final List<Map<String, dynamic>> _ubicaciones = [
    {
      'titulo': 'Sandboarding\nen Huacachina',
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
      'titulo': 'Reserva Nacional\nde Paracas',
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
      'titulo': 'Viñedos y bodegas',
      'subtitulo': 'Ica',
      'lat': -14.0678,
      'lng': -75.7286,
      'condicion': 'Excelente',
      'indice': '90/100',
      'categoria': 'Gastronomía',
      'imagen': 'assets/images/act_vinos.jpg',
      'imagenes_detalle': [
        'assets/images/act_vinos.jpg',
        'assets/images/detalle_vinos_2.jpg',
        'assets/images/detalle_vinos_3.jpg',
      ],
    },
  ];

  Map<String, dynamic>? _seleccionada;
  String _filtroActual = 'Todas';

  List<Map<String, dynamic>> get _ubicacionesFiltradas {
    if (_filtroActual == 'Todas') {
      return _ubicaciones;
    }
    return _ubicaciones.where((u) => u['categoria'] == _filtroActual).toList();
  }

  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColores.arenaFondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrar por categoría',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColores.marronOscuro,
                ),
              ),
              const SizedBox(height: 15),
              _itemFiltro('Todas'),
              _itemFiltro('Aventura'),
              _itemFiltro('Naturaleza'),
              _itemFiltro('Gastronomía'),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _itemFiltro(String titulo) {
    bool seleccionado = _filtroActual == titulo;
    return ListTile(
      title: Text(titulo),
      trailing: seleccionado
          ? const Icon(Icons.check, color: AppColores.naranjaBoton)
          : null,
      onTap: () {
        setState(() {
          _filtroActual = titulo;
          _seleccionada = null;
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final listaParaMostrar = _ubicacionesFiltradas;

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // 1. AppBar personalizado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  const Text(
                    'Mapa',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.filter_list,
                      color: AppColores.marronOscuro,
                      size: 28,
                    ),
                    onPressed: _mostrarFiltros,
                  ),
                ],
              ),
            ),

            // 2. Mapa
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
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _seleccionada = ubicacion;
                                });
                              },
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.teal,
                                size: 40,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // 3. Tarjeta inferior flotante
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
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  _seleccionada!['imagen'],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 70,
                                        height: 70,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.image,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _seleccionada!['titulo'].replaceAll(
                                        '\n',
                                        ' ',
                                      ),
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
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
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
                                Icons.arrow_forward_ios,
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
