import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../config/traducciones_scope.dart';
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

  final List<String> _categorias = [
    'Todas',
    'Aventura',
    'Naturaleza',
    'Cultura',
    'Gastronomía',
  ];

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
      if (_categoriaSeleccionada != 'Todas') {
        final cat = (actividad['categoria'] ?? '').toString().toLowerCase();
        final cats =
            (actividad['categorias'] as List<dynamic>?)
                ?.map((c) => c.toString().toLowerCase())
                .toList() ??
            [];
        final filtro = _categoriaSeleccionada.toLowerCase();
        final coincide =
            cat.contains(filtro) || cats.any((c) => c.contains(filtro));
        if (!coincide) return false;
      }

      if (_textoBusqueda.isNotEmpty) {
        final titulo = (actividad['titulo'] ?? '').toString().toLowerCase();
        final subtitulo = (actividad['subtitulo'] ?? '')
            .toString()
            .toLowerCase();
        final desc = (actividad['descripcion'] ?? '').toString().toLowerCase();
        final busqueda = _textoBusqueda.toLowerCase();
        return titulo.contains(busqueda) ||
            subtitulo.contains(busqueda) ||
            desc.contains(busqueda);
      }

      return true;
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
                      context.tr('actividades'),
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
                  hintText: context.tr('buscar_actividad'),
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
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categorias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categorias[index];
                  final seleccionada = _categoriaSeleccionada == cat;

                  String catTraducida = cat;
                  if (cat == 'Todas')
                    catTraducida = context.tr('categoria_todas');
                  if (cat == 'Aventura')
                    catTraducida = context.tr('categoria_aventura');
                  if (cat == 'Naturaleza')
                    catTraducida = context.tr('categoria_naturaleza');
                  if (cat == 'Cultura')
                    catTraducida = context.tr('categoria_cultura');
                  if (cat == 'Gastronomía')
                    catTraducida = context.tr('categoria_gastronomia');

                  return ChoiceChip(
                    label: Text(catTraducida),
                    selected: seleccionada,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _categoriaSeleccionada = cat);
                      }
                    },
                    selectedColor: AppColores.naranjaBoton,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: seleccionada
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: seleccionada ? Colors.white : colorTexto,
                    ),
                    backgroundColor: colorTarjeta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

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
                            context.tr('no_actividades'),
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
                                color: Colors.black.withValues(alpha: 0.05),
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
                                child: Builder(
                                  builder: (context) {
                                    final img = actividad['imagen'] ?? '';
                                    if (img.startsWith('assets/')) {
                                      return Image.asset(
                                        img,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    }
                                    return Image.network(
                                      img,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        'assets/images/carrusel_1_huacachina.jpg',
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
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
                              subtitle: Row(
                                children: [
                                  Text(
                                    actividad['subtitulo'] ?? 'Ica',
                                    style: TextStyle(
                                      color: colorTextoSecundario,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (actividad['categoria'] != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColores.naranjaBoton
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        actividad['categoria'].toString(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColores.naranjaBoton,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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

                                      atractivoId: actividad['id']?.toString(),
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
