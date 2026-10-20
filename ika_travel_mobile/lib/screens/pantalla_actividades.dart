import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../services/api_service.dart';
import 'pantalla_detalle.dart';

class PantallaActividades extends StatefulWidget {
  final VoidCallback? onVolverInicio;

  const PantallaActividades({super.key, this.onVolverInicio});

  @override
  State<PantallaActividades> createState() => _PantallaActividadesState();
}

class _PantallaActividadesState extends State<PantallaActividades> {
  final TextEditingController _buscadorController = TextEditingController();
  String _textoBusqueda = '';
  String _categoriaSeleccionada = 'Todas';

  List<Map<String, dynamic>> _actividades = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarActividades();
  }

  Future<void> _cargarActividades() async {
    final api = ApiService();
    final datos = await api.obtenerActividades();
    setState(() {
      _actividades = datos;
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _actividadesFiltradas {
    return _actividades.where((actividad) {
      final titulo = (actividad['titulo'] ?? '').toString().toLowerCase();
      final subtitulo = (actividad['subtitulo'] ?? '').toString().toLowerCase();
      final busqueda = _textoBusqueda.toLowerCase();
      final coincideTexto =
          titulo.contains(busqueda) || subtitulo.contains(busqueda);

      final categoriaActividad = actividad['categoria'] ?? 'General';
      final coincideCategoria =
          _categoriaSeleccionada == 'Todas' ||
          categoriaActividad == _categoriaSeleccionada;

      return coincideTexto && coincideCategoria;
    }).toList();
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listaParaMostrar = _actividadesFiltradas;

    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorTexto),
                    onPressed: () {
                      if (widget.onVolverInicio != null)
                        widget.onVolverInicio!();
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Actividades',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _buscadorController,
                onChanged: (value) => setState(() => _textoBusqueda = value),
                style: TextStyle(color: colorTexto),
                decoration: InputDecoration(
                  hintText: 'Buscar actividad o lugar',
                  hintStyle: TextStyle(
                    color: colorTextoSecundario,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: colorTextoSecundario),
                  filled: true,
                  fillColor: colorTarjeta,
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
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _chipCategoria('Todas'),
                  _chipCategoria('Aventura'),
                  _chipCategoria('Naturaleza'),
                  _chipCategoria('Gastronomía'),
                  _chipCategoria('Cultura'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColores.naranjaBoton,
                      ),
                    )
                  : listaParaMostrar.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 60,
                            color: colorTextoSecundario,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No se encontraron actividades',
                            style: TextStyle(
                              color: colorTextoSecundario,
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
                            color: colorTarjeta,
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
                                child: Image.network(
                                  actividad['imagen'] ??
                                      'https://via.placeholder.com/150',
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
                                actividad['titulo'] ?? 'Sin título',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: colorTexto,
                                  height: 1.2,
                                ),
                              ),
                              subtitle: Text(
                                actividad['subtitulo'] ?? 'Ica',
                                style: TextStyle(
                                  color: colorTextoSecundario,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: colorTextoSecundario,
                              ),
                              onTap: () {
                                // 👇 AQUÍ PASAMOS EL ID
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PantallaDetalle(
                                      id: actividad['id'], // 👈 EL ID
                                      titulo:
                                          actividad['titulo'] ?? 'Sin título',
                                      subtitulo:
                                          actividad['subtitulo'] ?? 'Ica',
                                      imagenes: List<String>.from(
                                        actividad['imagenes_detalle'] ??
                                            [actividad['imagen']],
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

  Widget _chipCategoria(String categoria) {
    final bool activo = _categoriaSeleccionada == categoria;
    final colorTexto = TemaApp.texto(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(categoria),
        selected: activo,
        onSelected: (selected) {
          setState(() {
            _categoriaSeleccionada = categoria;
          });
        },
        backgroundColor: colorTarjeta,
        selectedColor: AppColores.naranjaBoton,
        labelStyle: TextStyle(
          color: activo ? Colors.white : colorTexto,
          fontWeight: activo ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
    );
  }
}
