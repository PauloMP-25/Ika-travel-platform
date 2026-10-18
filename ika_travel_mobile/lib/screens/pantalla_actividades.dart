import 'dart:async';
import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/attraction_model.dart';
import '../services/attractions_service.dart';
import 'pantalla_detalle.dart';

class PantallaActividades extends StatefulWidget {
  final VoidCallback? onVolverInicio;
  final AttractionsService? attractionsService;

  const PantallaActividades({
    super.key,
    this.onVolverInicio,
    this.attractionsService,
  });

  @override
  State<PantallaActividades> createState() => _PantallaActividadesState();
}

class _PantallaActividadesState extends State<PantallaActividades> {
  final TextEditingController _buscadorController = TextEditingController();
  String _textoBusqueda = '';
  Timer? _debounceTimer;

  late final AttractionsService _service;
  bool _cargando = true;
  String? _errorMensaje;
  List<AttractionListItemModel> _atractivosServidor = [];

  // Datos de respaldo (fallback) por si el backend está desconectado o en modo offline
  final List<Map<String, dynamic>> _actividadesLocales = const [
    {
      'id': 'local-1',
      'titulo': 'Sandboarding\nen Huacachina',
      'subtitulo': 'Ica',
      'imagen': 'assets/images/detalle_sandboarding_1.jpg',
      'imagenes_detalle': [
        'assets/images/detalle_sandboarding_1.jpg',
        'assets/images/detalle_sandboarding_2.jpg',
        'assets/images/detalle_sandboarding_3.jpg',
      ],
    },
    {
      'id': 'local-2',
      'titulo': 'Paseo en buggy\nen las dunas',
      'subtitulo': 'Huacachina',
      'imagen': 'assets/images/act_buggy1.jpg',
      'imagenes_detalle': [
        'assets/images/act_buggy1.jpg',
        'assets/images/detalle_buggy_2.jpg',
        'assets/images/detalle_buggy_3.jpg',
      ],
    },
    {
      'id': 'local-3',
      'titulo': 'Islas Ballestas',
      'subtitulo': 'Paracas',
      'imagen': 'assets/images/act_ballestas1.jpg',
      'imagenes_detalle': [
        'assets/images/act_ballestas1.jpg',
        'assets/images/detalle_ballestas_2.jpg',
        'assets/images/detalle_ballestas_3.jpg',
      ],
    },
    {
      'id': 'local-4',
      'titulo': 'Reserva Nacional\nde Paracas',
      'subtitulo': 'Paracas',
      'imagen': 'assets/images/act_reserva1.jpg',
      'imagenes_detalle': [
        'assets/images/act_reserva1.jpg',
        'assets/images/detalle_reserva_2.jpg',
        'assets/images/detalle_reserva_3.jpg',
      ],
    },
    {
      'id': 'local-5',
      'titulo': 'Viñedos y bodegas',
      'subtitulo': 'Ica',
      'imagen': 'assets/images/act_vinos.jpg',
      'imagenes_detalle': [
        'assets/images/act_vinos.jpg',
        'assets/images/detalle_vinos_2.jpg',
        'assets/images/detalle_vinos_3.jpg',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.attractionsService ?? AttractionsService();
    _cargarAtractivos();
  }

  Future<void> _cargarAtractivos({String? search}) async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      final items = await _service.getAttractions(search: search);
      setState(() {
        _atractivosServidor = items;
        _cargando = false;
      });
    } catch (e) {
      // Si falla la conexión con el backend (e.g. sin red), usamos fallback local elegante
      setState(() {
        _atractivosServidor = [];
        _errorMensaje = 'Modo sin conexión: mostrando catálogo local.';
        _cargando = false;
      });
    }
  }

  void _onBusquedaChanged(String query) {
    _textoBusqueda = query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _cargarAtractivos(search: query.trim());
    });
  }

  List<Map<String, dynamic>> get _listaParaMostrar {
    if (_atractivosServidor.isNotEmpty) {
      return _atractivosServidor.map((a) => a.toMap()).toList();
    }
    // Fallback a filtrado de lista local
    if (_textoBusqueda.isEmpty) {
      return _actividadesLocales;
    }
    final busqueda = _textoBusqueda.toLowerCase();
    return _actividadesLocales.where((actividad) {
      final titulo = (actividad['titulo'] as String).toLowerCase();
      final subtitulo = (actividad['subtitulo'] as String).toLowerCase();
      return titulo.contains(busqueda) || subtitulo.contains(busqueda);
    }).toList();
  }

  Widget _construirImagen(String rutaImagen) {
    if (rutaImagen.startsWith('http://') || rutaImagen.startsWith('https://')) {
      return Image.network(
        rutaImagen,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 70,
          height: 70,
          color: Colors.grey[300],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }
    return Image.asset(
      rutaImagen,
      width: 70,
      height: 70,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 70,
        height: 70,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _buscadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _listaParaMostrar;

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Cabecera con volver
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColores.marronOscuro,
                    ),
                    onPressed: () {
                      if (widget.onVolverInicio != null) {
                        widget.onVolverInicio!();
                      }
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Actividades',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // 2. Barra de búsqueda reactiva
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _buscadorController,
                onChanged: _onBusquedaChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar actividad o lugar',
                  hintStyle: const TextStyle(
                    color: AppColores.grisTexto,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColores.grisTexto,
                  ),
                  suffixIcon: _textoBusqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColores.grisTexto),
                          onPressed: () {
                            _buscadorController.clear();
                            _onBusquedaChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (_errorMensaje != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMensaje!,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // 3. Contenido: Indicador de carga o listado
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColores.naranjaBoton,
                      ),
                    )
                  : items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No se encontraron actividades',
                                style: TextStyle(
                                  color: AppColores.grisTexto,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColores.naranjaBoton,
                          onRefresh: () => _cargarAtractivos(
                            search: _textoBusqueda.trim(),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final actividad = items[index];
                              final String imagen = actividad['imagen'] as String? ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(10),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: _construirImagen(imagen),
                                    ),
                                    title: Text(
                                      actividad['titulo'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColores.marronOscuro,
                                        height: 1.2,
                                      ),
                                    ),
                                    subtitle: Text(
                                      actividad['subtitulo'] ?? '',
                                      style: const TextStyle(
                                        color: AppColores.grisTexto,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: AppColores.grisTexto,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PantallaDetalle(
                                            titulo: actividad['titulo'] ?? '',
                                            subtitulo: actividad['subtitulo'] ?? '',
                                            imagenes: List<String>.from(
                                              actividad['imagenes_detalle'] ?? [imagen],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
