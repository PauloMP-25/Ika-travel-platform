import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/colores_tema.dart';
import '../config/navegacion_service.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/lugar_modelo.dart';
import '../services/lugares_service.dart';
import 'pantalla_detalle.dart';
import 'pantalla_mas.dart';

/// Mapa turístico de Ica.
///
/// Los lugares son los mismos que muestra la galería de Actividades: ambos
/// los piden a [LugaresService], que los trae de la base de datos. Cada pin se
/// colorea según su categoría, igual que en la galería.
class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa>
    with TickerProviderStateMixin {
  /// Vista general de la región.
  static const LatLng _centroIca = LatLng(-14.06402, -75.72907);
  static const double _zoomRegion = 9.5;

  /// Zoom al que se acerca el mapa cuando se elige un lugar concreto.
  static const double _zoomLugar = 16.0;

  final MapController _mapController = MapController();
  final TextEditingController _busquedaController = TextEditingController();
  final FocusNode _focusBusqueda = FocusNode();
  final LugaresService _lugaresService = LugaresService();

  AnimationController? _animMovimiento;

  List<LugarIca> _lugares = const [];
  List<String> _categorias = const [];
  bool _cargando = true;
  bool _mapaListo = false;

  String _textoBusqueda = '';
  String _filtroActual = 'Todas';
  LugarIca? _seleccionado;

  LatLng? _miUbicacion;
  bool _obteniendoGps = false;

  @override
  void initState() {
    super.initState();
    _busquedaController.addListener(() {
      if (_textoBusqueda == _busquedaController.text) return;
      setState(() => _textoBusqueda = _busquedaController.text);
    });
    _focusBusqueda.addListener(() => setState(() {}));
    NavegacionService.lugarEnfocadoNotifier.addListener(_atenderFoco);
    _cargarLugares();
    _centrarEnMiUbicacion(pedirPermiso: false, autoCentrar: false);
  }

  @override
  void dispose() {
    NavegacionService.lugarEnfocadoNotifier.removeListener(_atenderFoco);
    _animMovimiento?.dispose();
    _busquedaController.dispose();
    _focusBusqueda.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Datos
  // ------------------------------------------------------------------

  Future<void> _cargarLugares({bool forzar = false}) async {
    if (mounted) setState(() => _cargando = true);
    final lugares = await _lugaresService.obtenerLugares(forzarRecarga: forzar);
    final categorias = await _lugaresService.obtenerCategorias();
    if (!mounted) return;
    setState(() {
      _lugares = lugares;
      _categorias = categorias;
      _cargando = false;
    });
    // Si alguien pidió enfocar un lugar mientras cargábamos, lo atendemos ya.
    _atenderFoco();
  }

  /// Solo los lugares que tienen coordenadas pueden dibujarse en el mapa.
  List<LugarIca> get _conCoordenadas =>
      _lugares.where((l) => l.tieneCoordenadas).toList();

  List<LugarIca> get _filtrados => _lugaresService.filtrar(
    _conCoordenadas,
    categoria: _filtroActual,
    texto: _textoBusqueda,
  );

  // ------------------------------------------------------------------
  // Foco externo ("Ver en el mapa" desde el detalle)
  // ------------------------------------------------------------------

  void _atenderFoco() {
    final id = NavegacionService.lugarEnfocadoNotifier.value;
    if (id == null || _lugares.isEmpty) return;

    final lugar = _lugares.firstWhere(
      (l) => l.id == id,
      orElse: () => _lugares.first,
    );
    if (lugar.id != id || !lugar.tieneCoordenadas) {
      NavegacionService.lugarEnfocadoNotifier.value = null;
      return;
    }

    NavegacionService.lugarEnfocadoNotifier.value = null;
    // Esperamos el frame para que el mapa ya esté montado y con tamaño.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seleccionarLugar(lugar);
    });
  }

  // ------------------------------------------------------------------
  // Movimiento del mapa
  // ------------------------------------------------------------------

  void _seleccionarLugar(LugarIca lugar, {double zoom = _zoomLugar}) {
    setState(() => _seleccionado = lugar);
    _focusBusqueda.unfocus();
    final destino = lugar.coordenadas;
    if (destino != null) _moverAnimado(destino, zoom);
  }

  /// Desplaza y acerca el mapa suavemente hasta un punto.
  void _moverAnimado(LatLng destino, double zoomFinal) {
    if (!_mapaListo) {
      // El mapa aún no se ha dibujado: lo posicionamos sin animar.
      try {
        _mapController.move(destino, zoomFinal);
      } catch (_) {
        /* Se reintentará cuando el mapa esté listo. */
      }
      return;
    }

    final camara = _mapController.camera;
    final latDesde = camara.center.latitude;
    final lonDesde = camara.center.longitude;
    final zoomDesde = camara.zoom;

    _animMovimiento?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _animMovimiento = controller;

    final curva = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    controller.addListener(() {
      final t = curva.value;
      _mapController.move(
        LatLng(
          latDesde + (destino.latitude - latDesde) * t,
          lonDesde + (destino.longitude - lonDesde) * t,
        ),
        zoomDesde + (zoomFinal - zoomDesde) * t,
      );
    });
    controller.forward();
  }

  void _verRegionCompleta() {
    setState(() => _seleccionado = null);
    _moverAnimado(_centroIca, _zoomRegion);
  }

  Future<void> _centrarEnMiUbicacion({
    bool pedirPermiso = true,
    bool autoCentrar = true,
  }) async {
    setState(() => _obteniendoGps = true);
    try {
      final gpsHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!gpsHabilitado) {
        if (mounted && pedirPermiso) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('gps_encender_msg')),
              action: SnackBarAction(
                label: context.tr('ajustes'),
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied && pedirPermiso) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.whileInUse ||
          permiso == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        final nuevaUbi = LatLng(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() => _miUbicacion = nuevaUbi);
        if (autoCentrar) _moverAnimado(nuevaUbi, 15.0);
      } else if (pedirPermiso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('gps_permiso_requerido'))),
        );
      }
    } catch (e) {
      debugPrint('[PantallaMapa] Error obteniendo GPS: $e');
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  // ------------------------------------------------------------------
  // Filtros
  // ------------------------------------------------------------------

  void _mostrarFiltros() {
    final colorFondo = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colorFondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('filtrar_categoria'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorTexto,
                ),
              ),
              const SizedBox(height: 14),
              _opcionFiltro('Todas', colorTexto),
              for (final categoria in _categorias)
                _opcionFiltro(categoria, colorTexto),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcionFiltro(String categoria, Color colorTexto) {
    final esTodas = categoria == 'Todas';
    final seleccionado = _filtroActual == categoria;
    final estilo = CategoriasLugar.estilo(categoria);
    final color = esTodas ? AppColores.naranjaBoton : estilo.color;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          esTodas ? Icons.apps_rounded : estilo.icono,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        esTodas ? context.tr('categoria_todas') : categoria,
        style: TextStyle(
          color: colorTexto,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: seleccionado ? Icon(Icons.check_rounded, color: color) : null,
      onTap: () {
        setState(() {
          _filtroActual = categoria;
          _seleccionado = null;
        });
        Navigator.pop(context);
      },
    );
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final visibles = _filtrados;

    final sugerencias = _textoBusqueda.trim().isNotEmpty
        ? visibles.take(4).toList()
        : const <LugarIca>[];

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(colorTexto),
            Expanded(
              child: Stack(
                children: [
                  _mapa(visibles),
                  _barraBusqueda(sugerencias, visibles),
                  if (_cargando) _avisoCargando(),
                  if (!_cargando && _lugaresService.usandoMocks)
                    _avisoSinConexion(),
                  _contadorYBotones(visibles),
                  if (_seleccionado != null) _tarjetaSeleccion(_seleccionado!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(Color colorTexto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: colorTexto, size: 26),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PantallaMas()),
            ),
          ),
          Expanded(
            child: Text(
              context.tr('mapa_turistico'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: colorTexto,
              ),
            ),
          ),
          IconButton(
            tooltip: context.tr('filtrar_categoria'),
            icon: Icon(
              _filtroActual == 'Todas'
                  ? Icons.filter_list_rounded
                  : Icons.filter_alt_rounded,
              color: _filtroActual == 'Todas'
                  ? colorTexto
                  : CategoriasLugar.estilo(_filtroActual).color,
              size: 26,
            ),
            onPressed: _mostrarFiltros,
          ),
        ],
      ),
    );
  }

  Widget _mapa(List<LugarIca> visibles) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _centroIca,
        initialZoom: _zoomRegion,
        minZoom: 5,
        maxZoom: 18,
        onMapReady: () {
          _mapaListo = true;
          _atenderFoco();
        },
        onTap: (_, __) {
          _focusBusqueda.unfocus();
          if (_seleccionado != null) setState(() => _seleccionado = null);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ika_travel_mobile',
        ),
        MarkerLayer(
          markers: [
            if (_miUbicacion != null) _marcadorMiUbicacion(_miUbicacion!),
            for (final lugar in visibles) _marcadorLugar(lugar),
          ],
        ),
      ],
    );
  }

  Marker _marcadorMiUbicacion(LatLng punto) {
    return Marker(
      point: punto,
      width: 44,
      height: 44,
      child: Tooltip(
        message: context.tr('mi_ubicacion_gps'),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1976D2).withValues(alpha: 0.25),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1976D2),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _marcadorLugar(LugarIca lugar) {
    final seleccionado = _seleccionado?.id == lugar.id;
    final estilo = lugar.estilo;
    final tamano = seleccionado ? 50.0 : 40.0;

    return Marker(
      point: lugar.coordenadas!,
      width: tamano,
      height: tamano,
      child: GestureDetector(
        onTap: () => _seleccionarLugar(lugar),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: estilo.color,
            border: Border.all(
              color: Colors.white,
              width: seleccionado ? 3.5 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: estilo.color.withValues(alpha: seleccionado ? 0.5 : 0.3),
                blurRadius: seleccionado ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            estilo.icono,
            color: Colors.white,
            size: seleccionado ? 26 : 21,
          ),
        ),
      ),
    );
  }

  Widget _barraBusqueda(List<LugarIca> sugerencias, List<LugarIca> visibles) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    return Positioned(
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
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
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
                hintText: context.tr('buscar_lugares_hint'),
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: colorTextoSecundario,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColores.naranjaBoton,
                  size: 24,
                ),
                suffixIcon: _textoBusqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        color: colorTextoSecundario,
                        onPressed: _busquedaController.clear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) {
                if (visibles.isNotEmpty) _seleccionarLugar(visibles.first);
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
                    color: Colors.black.withValues(alpha: 0.12),
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
                  color: colorTextoSecundario.withValues(alpha: 0.2),
                ),
                itemBuilder: (context, idx) {
                  final lugar = sugerencias[idx];
                  final estilo = lugar.estilo;
                  return ListTile(
                    dense: true,
                    leading: Icon(estilo.icono, color: estilo.color, size: 22),
                    title: Text(
                      lugar.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                    subtitle: Text(
                      '${lugar.distrito} • ${lugar.categoriaPrincipal}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorTextoSecundario,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.north_west_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () => _seleccionarLugar(lugar),
                  );
                },
              ),
            ),
          if (!_cargando && _textoBusqueda.isNotEmpty && visibles.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorTarjeta,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.tr('no_lugares_con')} "$_textoBusqueda"',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorTextoSecundario,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busquedaController.clear,
                    child: Text(context.tr('limpiar')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _avisoCargando() {
    return Positioned(
      top: 76,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: TemaApp.tarjeta(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColores.naranjaBoton,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('cargando_lugares'),
                style: TextStyle(fontSize: 12, color: TemaApp.texto(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Avisa que los lugares salen del catálogo local porque no hubo conexión.
  Widget _avisoSinConexion() {
    return Positioned(
      top: 76,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColores.naranjaBoton.withValues(alpha: 0.4)),
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
                  color: AppColores.marronOscuro,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _cargarLugares(forzar: true),
              child: Text(
                context.tr('reintentar'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contadorYBotones(List<LugarIca> visibles) {
    final colorTarjeta = TemaApp.tarjeta(context);
    final abajo = _seleccionado != null ? 158.0 : 20.0;

    return Positioned(
      left: 16,
      right: 16,
      bottom: abajo,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colorTarjeta.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pin_drop_rounded,
                    size: 15, color: AppColores.naranjaBoton),
                const SizedBox(width: 6),
                Text(
                  '${visibles.length} ${context.tr('encontrados')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: TemaApp.texto(context),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'btn_mi_ubicacion_gps',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1976D2),
                elevation: 4,
                tooltip: context.tr('ir_mi_ubicacion'),
                onPressed: () => _centrarEnMiUbicacion(),
                child: _obteniendoGps
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF1976D2),
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 24),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.small(
                heroTag: 'btn_centrar_mapa',
                backgroundColor: colorTarjeta,
                foregroundColor: AppColores.naranjaBoton,
                elevation: 3,
                tooltip: context.tr('ver_todo_ica'),
                onPressed: _verRegionCompleta,
                child: const Icon(Icons.zoom_out_map_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaSeleccion(LugarIca lugar) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final estilo = lugar.estilo;

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Material(
        color: colorTarjeta,
        borderRadius: BorderRadius.circular(18),
        elevation: 8,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _abrirDetalle(lugar),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                          fontSize: 15,
                          height: 1.2,
                          color: colorTexto,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                                fontSize: 12,
                                color: colorTextoSecundario,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chipCategoria(lugar.categoriaPrincipal, estilo),
                          _chipVerDetalle(),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr('cerrar_tarjeta'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: colorTextoSecundario,
                  onPressed: () => setState(() => _seleccionado = null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniatura(LugarIca lugar) {
    final imagen = lugar.imagenPrincipal;
    final esAsset = imagen.startsWith('assets/');

    Widget respaldo() => Container(
      width: 74,
      height: 74,
      color: lugar.estilo.color.withValues(alpha: 0.15),
      child: Icon(lugar.estilo.icono, color: lugar.estilo.color, size: 28),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: esAsset
          ? Image.asset(
              imagen,
              width: 74,
              height: 74,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => respaldo(),
            )
          : Image.network(
              imagen,
              width: 74,
              height: 74,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => respaldo(),
            ),
    );
  }

  Widget _chipCategoria(String categoria, EstiloCategoria estilo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estilo.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        categoria,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: estilo.color,
        ),
      ),
    );
  }

  Widget _chipVerDetalle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColores.naranjaBoton,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('ver_detalle'),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.arrow_forward_rounded, size: 11, color: Colors.white),
        ],
      ),
    );
  }

  void _abrirDetalle(LugarIca lugar) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PantallaDetalle(lugar: lugar)),
    );
  }
}
