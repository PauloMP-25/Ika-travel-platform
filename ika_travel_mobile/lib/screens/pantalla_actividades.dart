import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/navegacion_service.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/lugar_modelo.dart';
import '../services/lugares_service.dart';
import 'pantalla_detalle.dart';

/// Galería de lugares turísticos.
///
/// Comparte la fuente de datos con el mapa ([LugaresService], que los trae de
/// la base de datos), así que los dos muestran exactamente los mismos lugares,
/// con los mismos nombres, categorías y colores.
class PantallaActividades extends StatefulWidget {
  final VoidCallback? onVolverInicio;

  const PantallaActividades({super.key, this.onVolverInicio});

  @override
  State<PantallaActividades> createState() => _PantallaActividadesState();
}

class _PantallaActividadesState extends State<PantallaActividades> {
  final TextEditingController _buscadorController = TextEditingController();
  final LugaresService _lugaresService = LugaresService();

  List<LugarIca> _lugares = const [];
  List<String> _categorias = const [];
  bool _cargando = true;

  String _textoBusqueda = '';
  String _categoriaSeleccionada = 'Todas';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool forzar = false}) async {
    if (mounted) setState(() => _cargando = true);
    final lugares = await _lugaresService.obtenerLugares(forzarRecarga: forzar);
    final categorias = await _lugaresService.obtenerCategorias(
      forzarRecarga: forzar,
    );
    if (!mounted) return;
    setState(() {
      _lugares = lugares;
      _categorias = categorias;
      _cargando = false;
    });
  }

  List<LugarIca> get _filtrados => _lugaresService.filtrar(
    _lugares,
    categoria: _categoriaSeleccionada,
    texto: _textoBusqueda,
  );

  /// Traduce las categorías conocidas; las nuevas de la BD se muestran tal cual.
  String _etiquetaCategoria(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'todas':
        return context.tr('categoria_todas');
      case 'aventura':
        return context.tr('categoria_aventura');
      case 'naturaleza':
        return context.tr('categoria_naturaleza');
      case 'cultural':
      case 'cultura':
        return context.tr('categoria_cultura');
      case 'gastronomía y vino':
      case 'gastronomia y vino':
      case 'gastronomía':
      case 'gastronomia':
        return context.tr('categoria_gastronomia');
      default:
        return categoria;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final visibles = _filtrados;

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(colorTexto, visibles.length),
            _buscador(),
            const SizedBox(height: 12),
            _chipsCategorias(colorTexto),
            if (!_cargando && _lugaresService.usandoMocks) _avisoSinConexion(),
            const SizedBox(height: 10),
            Expanded(child: _contenido(visibles)),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(Color colorTexto, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colorTexto),
            onPressed: () => widget.onVolverInicio?.call(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  context.tr('actividades'),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
                if (!_cargando)
                  Text(
                    '$total ${context.tr('lugares_en_ica')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: TemaApp.textoSecundario(context),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('ver_en_mapa'),
            icon: const Icon(Icons.map_rounded,
                color: AppColores.turquesaOasis),
            onPressed: () => NavegacionService.irAMapa(),
          ),
        ],
      ),
    );
  }

  Widget _buscador() {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _buscadorController,
        onChanged: (valor) => setState(() => _textoBusqueda = valor),
        style: TextStyle(color: colorTexto),
        decoration: InputDecoration(
          hintText: context.tr('buscar_actividad'),
          hintStyle: TextStyle(color: colorTextoSecundario, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColores.naranjaBoton),
          suffixIcon: _textoBusqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  color: colorTextoSecundario,
                  onPressed: () {
                    _buscadorController.clear();
                    setState(() => _textoBusqueda = '');
                  },
                )
              : null,
          filled: true,
          fillColor: TemaApp.tarjeta(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: AppColores.naranjaBoton,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipsCategorias(Color colorTexto) {
    final opciones = ['Todas', ..._categorias];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: opciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final categoria = opciones[index];
          final esTodas = categoria == 'Todas';
          final seleccionada = _categoriaSeleccionada == categoria;
          final estilo = CategoriasLugar.estilo(categoria);
          final color = esTodas ? AppColores.naranjaBoton : estilo.color;

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _categoriaSeleccionada = categoria),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: seleccionada ? color : TemaApp.tarjeta(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: seleccionada
                      ? color
                      : color.withValues(alpha: 0.35),
                  width: 1.3,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    esTodas ? Icons.apps_rounded : estilo.icono,
                    size: 15,
                    color: seleccionada ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _etiquetaCategoria(categoria),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: seleccionada
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: seleccionada ? Colors.white : colorTexto,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _avisoSinConexion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColores.naranjaBoton.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 16, color: AppColores.naranjaBoton),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('modo_sin_conexion_lugares'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColores.marronOscuro,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _cargar(forzar: true),
              child: Text(
                context.tr('reintentar'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido(List<LugarIca> visibles) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColores.naranjaBoton),
      );
    }

    if (visibles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 58, color: TemaApp.textoSecundario(context)),
              const SizedBox(height: 12),
              Text(
                context.tr('no_actividades'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TemaApp.textoSecundario(context),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () {
                  _buscadorController.clear();
                  setState(() {
                    _textoBusqueda = '';
                    _categoriaSeleccionada = 'Todas';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.tr('limpiar')),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColores.naranjaBoton,
      onRefresh: () => _cargar(forzar: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: visibles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _tarjetaLugar(visibles[index]),
      ),
    );
  }

  Widget _tarjetaLugar(LugarIca lugar) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final estilo = lugar.estilo;

    return Material(
      color: TemaApp.tarjeta(context),
      borderRadius: BorderRadius.circular(16),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PantallaDetalle(lugar: lugar)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _miniatura(lugar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lugar.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        height: 1.25,
                        color: colorTexto,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 13, color: colorTextoSecundario),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            lugar.distrito,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colorTextoSecundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: estilo.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(estilo.icono,
                                    size: 11, color: estilo.color),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _etiquetaCategoria(lugar.categoriaPrincipal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: estilo.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (lugar.tieneCoordenadas) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: context.tr('ver_en_mapa'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            icon: const Icon(Icons.map_rounded, size: 17),
                            color: AppColores.turquesaOasis,
                            onPressed: () => NavegacionService.irAMapaConLugar(
                              lugar.id,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 15, color: colorTextoSecundario),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniatura(LugarIca lugar) {
    final imagen = lugar.imagenPrincipal;
    final estilo = lugar.estilo;

    Widget respaldo() => Container(
      width: 76,
      height: 76,
      color: estilo.color.withValues(alpha: 0.15),
      child: Icon(estilo.icono, color: estilo.color, size: 28),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imagen.startsWith('assets/')
          ? Image.asset(
              imagen,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => respaldo(),
            )
          : Image.network(
              imagen,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => respaldo(),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : respaldo(),
            ),
    );
  }
}
