import 'package:flutter/material.dart';

import '../config/tema.dart';
import 'pantalla_detalle.dart';

class PantallaActividades extends StatefulWidget {
  final VoidCallback? onVolverInicio;

  const PantallaActividades({super.key, this.onVolverInicio});

  @override
  State<PantallaActividades> createState() => _PantallaActividadesState();
}

class _PantallaActividadesState extends State<PantallaActividades> {
  // 1. Controlador para la barra de búsqueda
  final TextEditingController _buscadorController = TextEditingController();
  String _textoBusqueda = '';

  // Datos falsos (mock) de las actividades
  final List<Map<String, dynamic>> actividades = const [
    {
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

  // 2. Lógica de filtrado
  List<Map<String, dynamic>> get _actividadesFiltradas {
    if (_textoBusqueda.isEmpty) {
      return actividades; // Si no hay búsqueda, devuelve todas
    }
    return actividades.where((actividad) {
      final titulo = actividad['titulo'].toLowerCase();
      final subtitulo = actividad['subtitulo'].toLowerCase();
      final busqueda = _textoBusqueda.toLowerCase();

      // Devuelve true si el texto buscado está en el título o en el subtítulo
      return titulo.contains(busqueda) || subtitulo.contains(busqueda);
    }).toList();
  }

  @override
  void dispose() {
    _buscadorController.dispose(); // Limpiar el controlador al salir
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listaParaMostrar = _actividadesFiltradas; // Lista ya filtrada

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Título "Actividades" con la flechita de volver
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

            // 2. Barra de búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _buscadorController,
                // 👇 Lógica que actualiza el filtro mientras escribes
                onChanged: (value) {
                  setState(() {
                    _textoBusqueda = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar actividad o lugar',
                  hintStyle: TextStyle(
                    color: AppColores.grisTexto,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColores.grisTexto,
                  ),
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
            const SizedBox(height: 16),

            // 3. Lista de actividades (AHORA FILTRADA)
            Expanded(
              child: listaParaMostrar.isEmpty
                  // 👇 Mensaje si no se encuentra ninguna actividad
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
                          Text(
                            'No se encontraron actividades',
                            style: TextStyle(
                              color: AppColores.grisTexto,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: listaParaMostrar.length,
                      itemBuilder: (context, index) {
                        final actividad = listaParaMostrar[index];
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
                                child: Image.asset(
                                  actividad['imagen'],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              title: Text(
                                actividad['titulo'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColores.marronOscuro,
                                  height: 1.2,
                                ),
                              ),
                              subtitle: Text(
                                actividad['subtitulo'],
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
                                      titulo: actividad['titulo'],
                                      subtitulo: actividad['subtitulo'],
                                      imagenes: List<String>.from(
                                        actividad['imagenes_detalle'],
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
          ],
        ),
      ),
    );
  }
}
