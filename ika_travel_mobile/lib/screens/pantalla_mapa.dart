import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import 'pantalla_detalle.dart';
import 'pantalla_mas.dart';

class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  final MapController _mapController = MapController();
  final TextEditingController _busquedaController = TextEditingController();
  final FocusNode _focusBusqueda = FocusNode();

  String _textoBusqueda = '';
  String _filtroActual = 'Todas';
  Map<String, dynamic>? _seleccionada;

  // 👇 Agregué 'id' a cada ubicación para que la pantalla de detalle funcione
  final List<Map<String, dynamic>> _ubicaciones = [
    {
      'id': '05cc56f2-3c08-4efa-aece-885ad4fffbac',
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
      'id': '1b0ce57c-f462-46f5-8b99-bbd791e8ed17',
      'titulo': 'Laguna de Huacachina',
      'subtitulo': 'Ica',
      'lat': -14.0870,
      'lng': -75.7632,
      'condicion': 'Excelente',
      'indice': '94/100',
      'categoria': 'Naturaleza',
      'imagen': 'assets/images/carrusel_1_huacachina.jpg',
      'imagenes_detalle': [
        'assets/images/carrusel_1_huacachina.jpg',
        'assets/images/detalle_sandboarding_1.jpg',
      ],
    },
    {
      'id': '6ebab421-455b-47f1-b197-647133fd2483',
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
      'id': 'b8afbadd-4e7f-4532-a081-973a3f850c8e',
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
      'id': 'cec5287f-f62e-4188-8066-855eb907fec7',
      'titulo': 'Viñedos y Bodega Tacama',
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
    {
      'id': '82dace36-4f88-462e-9167-ddd9b9845ce8',
      'titulo': 'Museo Regional de Ica',
      'subtitulo': 'Ica',
      'lat': -14.0685,
      'lng': -75.7288,
      'condicion': 'Excelente',
      'indice': '92/100',
      'categoria': 'Cultura',
      'imagen': 'assets/images/carrusel_2_vinos.jpg',
      'imagenes_detalle': ['assets/images/carrusel_2_vinos.jpg'],
    },
    {
      'id': 'a63285f5-67a9-43e7-8869-26bdcb7d041e',
      'titulo': 'Playa El Chaco',
      'subtitulo': 'Paracas',
      'lat': -14.0722,
      'lng': -75.7258,
      'condicion': 'Excelente',
      'indice': '89/100',
      'categoria': 'Naturaleza',
      'imagen': 'assets/images/act_buggy1.jpg',
      'imagenes_detalle': ['assets/images/act_buggy1.jpg'],
    },
    {
      'id': 'ef71b81e-27ba-4709-b0d1-38654b344f4d',
      'titulo': 'Paseo en buggy en las dunas',
      'subtitulo': 'Huacachina',
      'lat': -14.0911,
      'lng': -75.7198,
      'condicion': 'Bueno',
      'indice': '82/100',
      'categoria': 'Aventura',
      'imagen': 'assets/images/detalle_buggy_2.jpg',
      'imagenes_detalle': ['assets/images/detalle_buggy_2.jpg'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _busquedaController.addListener(() {
      setState(() {
        _textoBusqueda = _busquedaController.text;
      });
    });
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _focusBusqueda.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _ubicacionesFiltradas {
    return _ubicaciones.where((u) {
      final coincideCategoria =
          _filtroActual == 'Todas' || u['categoria'] == _filtroActual;
      if (!coincideCategoria) return false;

      if (_textoBusqueda.trim().isEmpty) return true;

      final query = _textoBusqueda.trim().toLowerCase();
      final titulo = (u['titulo'] as String).toLowerCase();
      final subtitulo = (u['subtitulo'] as String).toLowerCase();
      final categoria = (u['categoria'] as String).toLowerCase();

      return titulo.contains(query) ||
          subtitulo.contains(query) ||
          categoria.contains(query);
    }).toList();
  }

  void _seleccionarLugar(Map<String, dynamic> lugar) {
    setState(() {
      _seleccionada = lugar;
    });
    _focusBusqueda.unfocus();
    _mapController.move(LatLng(lugar['lat'], lugar['lng']), 13.0);
  }

  void _centrarMapaGeneral() {
    _mapController.move(const LatLng(-14.0678, -75.7286), 9.5);
  }

  void _mostrarFiltros() {
    final colorFondo = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colorFondo,
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
              Text(
                'Filtrar por categoría',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorTexto,
                ),
              ),
              const SizedBox(height: 15),
              _itemFiltro('Todas', colorTexto),
              _itemFiltro('Aventura', colorTexto),
              _itemFiltro('Naturaleza', colorTexto),
              _itemFiltro('Gastronomía', colorTexto),
              _itemFiltro('Cultura', colorTexto),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _itemFiltro(String titulo, Color colorTexto) {
    bool seleccionado = _filtroActual == titulo;
    return ListTile(
      title: Text(titulo, style: TextStyle(color: colorTexto)),
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
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    final sugerencias = _textoBusqueda.trim().isNotEmpty
        ? _ubicacionesFiltradas.take(4).toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: colorTexto, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaMas(),
                        ),
                      );
                    },
                  ),
                  Text(
                    'Mapa Turístico',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Filtrar por categoría',
                    icon: Icon(
                      _filtroActual == 'Todas'
                          ? Icons.filter_list
                          : Icons.filter_alt,
                      color: _filtroActual == 'Todas'
                          ? colorTexto
                          : AppColores.naranjaBoton,
                      size: 28,
                    ),
                    onPressed: _mostrarFiltros,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      initialCenter: LatLng(-14.0678, -75.7286),
                      initialZoom: 9.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.ika_travel_mobile',
                      ),
                      MarkerLayer(
                        markers: listaParaMostrar.map((ubicacion) {
                          final esSeleccionada =
                              _seleccionada?['titulo'] == ubicacion['titulo'];
                          return Marker(
                            point: LatLng(ubicacion['lat'], ubicacion['lng']),
                            width: esSeleccionada ? 52 : 42,
                            height: esSeleccionada ? 52 : 42,
                            child: GestureDetector(
                              onTap: () => _seleccionarLugar(ubicacion),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: esSeleccionada
                                      ? AppColores.naranjaBoton
                                      : Colors.teal.shade700,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: esSeleccionada ? 3 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: esSeleccionada ? 10 : 4,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  esSeleccionada
                                      ? Icons.star_rounded
                                      : Icons.location_on,
                                  color: Colors.white,
                                  size: esSeleccionada ? 30 : 24,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: colorTarjeta,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _busquedaController,
                            focusNode: _focusBusqueda,
                            style: TextStyle(fontSize: 15, color: colorTexto),
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar lugares, huacachina, viñedos...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: colorTextoSecundario,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColores.naranjaBoton,
                                size: 24,
                              ),
                              suffixIcon: _textoBusqueda.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      color: colorTextoSecundario,
                                      onPressed: () {
                                        _busquedaController.clear();
                                        setState(() => _textoBusqueda = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (texto) {
                              if (listaParaMostrar.isNotEmpty) {
                                _seleccionarLugar(listaParaMostrar.first);
                              }
                            },
                          ),
                        ),
                        if (_focusBusqueda.hasFocus && sugerencias.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: colorTarjeta,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: sugerencias.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                thickness: 0.5,
                                color: colorTextoSecundario.withOpacity(0.2),
                              ),
                              itemBuilder: (context, idx) {
                                final lugar = sugerencias[idx];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.place_outlined,
                                    color: AppColores.naranjaBoton,
                                    size: 22,
                                  ),
                                  title: Text(
                                    lugar['titulo'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colorTexto,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${lugar['subtitulo']} • ${lugar['categoria']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorTextoSecundario,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.north_west,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onTap: () => _seleccionarLugar(lugar),
                                );
                              },
                            ),
                          ),
                        if (_textoBusqueda.isNotEmpty &&
                            listaParaMostrar.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: colorTarjeta,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_off,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No hay lugares con "$_textoBusqueda"',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorTextoSecundario,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _busquedaController.clear(),
                                  child: const Text('Limpiar'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: _seleccionada != null ? 150 : 20,
                    child: FloatingActionButton.small(
                      heroTag: 'btn_centrar_mapa',
                      backgroundColor: colorTarjeta,
                      foregroundColor: AppColores.naranjaBoton,
                      elevation: 4,
                      tooltip: 'Centrar vista de Ica',
                      onPressed: _centrarMapaGeneral,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                  if (_textoBusqueda.isNotEmpty || _filtroActual != 'Todas')
                    Positioned(
                      left: 16,
                      bottom: _seleccionada != null ? 150 : 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorTarjeta.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pin_drop,
                              size: 14,
                              color: AppColores.naranjaBoton,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${listaParaMostrar.length} encontrados',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_seleccionada != null)
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaDetalle(
                                id: _seleccionada!['id'], // 👈 AQUÍ EL ID
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
                            color: colorTarjeta,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  _seleccionada!['imagen'],
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 72,
                                        height: 72,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.image,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _seleccionada!['titulo'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: colorTexto,
                                      ),
                                    ),
                                    Text(
                                      '${_seleccionada!['subtitulo']} • ${_seleccionada!['categoria']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorTextoSecundario,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
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
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: colorTexto,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cerrar tarjeta',
                                icon: const Icon(Icons.close, size: 20),
                                color: colorTextoSecundario,
                                onPressed: () =>
                                    setState(() => _seleccionada = null),
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
