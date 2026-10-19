import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../services/api_service.dart'; // 👈 NUEVO: Importamos el servicio
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

  // 👇 Variables para los datos del backend
  List<Map<String, dynamic>> _actividades = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarActividades(); // 👈 Cargamos al abrir la pantalla
  }

  // Función para obtener las actividades del backend
  Future<void> _cargarActividades() async {
    final api = ApiService();
    final datos = await api.obtenerActividades();
    setState(() {
      _actividades = datos;
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _actividadesFiltradas {
    if (_textoBusqueda.isEmpty) return _actividades;
    return _actividades.where((actividad) {
      final titulo = (actividad['titulo'] ?? '').toString().toLowerCase();
      final subtitulo = (actividad['subtitulo'] ?? '').toString().toLowerCase();
      final busqueda = _textoBusqueda.toLowerCase();
      return titulo.contains(busqueda) || subtitulo.contains(busqueda);
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
                      if (widget.onVolverInicio != null) {
                        widget.onVolverInicio!();
                      }
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
                onChanged: (value) {
                  setState(() {
                    _textoBusqueda = value;
                  });
                },
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
            const SizedBox(height: 16),

            // 👇 Indicador de carga mientras se conecta al backend
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
                                // 👇 Usamos Image.network porque la imagen viene del backend
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PantallaDetalle(
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
}
