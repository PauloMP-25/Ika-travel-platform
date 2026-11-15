import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/favoritos_manager.dart';
import '../config/navegacion_service.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/alerta_modelo.dart';
import '../models/lugar_modelo.dart';
import '../services/alertas_service.dart';
import '../services/auth_service.dart';
import '../services/lugares_service.dart';
import '../services/weather_service.dart';
import 'pantalla_detalle_alerta.dart';
import 'pantalla_detalle_dia.dart';
import 'pantalla_login.dart';
import 'pantalla_seguimiento_destino.dart';

/// Detalle de un lugar del catálogo.
///
/// Recibe el [LugarIca] que la galería o el mapa ya tienen y, al abrirse, pide
/// a la base de datos el detalle completo (descripción, imágenes, coordenadas)
/// con [LugaresService.obtenerDetalle]. Si no hay conexión se queda con lo que
/// recibió, así que la pantalla nunca aparece vacía.
class PantallaDetalle extends StatefulWidget {
  final LugarIca lugar;

  const PantallaDetalle({super.key, required this.lugar});

  @override
  State<PantallaDetalle> createState() => _PantallaDetalleState();
}

class _PantallaDetalleState extends State<PantallaDetalle> {
  final AlertasService _alertasService = AlertasService();
  final WeatherService _weatherService = WeatherService();
  final LugaresService _lugaresService = LugaresService();

  late LugarIca _lugar;
  int _paginaActual = 0;

  Map<String, dynamic>? _climaActual;
  bool _cargandoClima = true;

  @override
  void initState() {
    super.initState();
    _lugar = widget.lugar;
    _cargarDetalle();
    _cargarClima();
  }

  /// Completa el lugar con el detalle de la base de datos.
  Future<void> _cargarDetalle() async {
    final completo = await _lugaresService.obtenerDetalle(widget.lugar);
    if (mounted) setState(() => _lugar = completo);
  }

  Future<void> _cargarClima() async {
    try {
      final clima = await _weatherService.obtenerClimaActual(
        destino: _lugar.distrito,
      );
      if (mounted) {
        setState(() {
          _climaActual = clima;
          _cargandoClima = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoClima = false);
    }
  }

  /// Salta a la pestaña del mapa y acerca la vista a este lugar.
  void _verEnMapa() {
    if (!_lugar.tieneCoordenadas) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('lugar_sin_coordenadas'))),
      );
      return;
    }
    NavegacionService.irAMapaConLugar(_lugar.id, context);
  }

  void _alternarFavorito() {
    final usuario = AuthService().usuarioActual;
    if (usuario == null || usuario.esInvitado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('inicia_sesion_favoritos')),
          action: SnackBarAction(
            label: context.tr('ingresar'),
            textColor: AppColores.naranjaBoton,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PantallaLogin(abrirComoModal: true),
              ),
            ),
          ),
        ),
      );
      return;
    }
    toggleFavorito(_lugar.aFavorito());
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _portada(),
              const SizedBox(height: 16),
              _avisoAlerta(),
              _accionesPrincipales(),
              if (_lugar.descripcion.isNotEmpty)
                _bloqueTexto(
                  titulo: context.tr('sobre_este_lugar'),
                  cuerpo: _lugar.descripcion,
                  colorTexto: colorTexto,
                  colorTextoSecundario: colorTextoSecundario,
                  colorTarjeta: colorTarjeta,
                ),
              if (_lugar.recomendacionOficial != null &&
                  _lugar.recomendacionOficial!.isNotEmpty)
                _recomendacionOficial(colorTexto),
              _tarjetaRecomendacionIA(
                colorTexto,
                colorTextoSecundario,
                colorTarjeta,
              ),
              const SizedBox(height: 18),
              _tarjetaSeguimiento(
                colorTexto,
                colorTextoSecundario,
                colorTarjeta,
              ),
              const SizedBox(height: 18),
              _factoresClima(colorTexto, colorTextoSecundario, colorTarjeta),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Portada
  // ------------------------------------------------------------------

  Widget _portada() {
    final imagenes = _lugar.imagenesDetalle;
    final estilo = _lugar.estilo;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      child: Stack(
        children: [
          SizedBox(
            height: 320,
            width: double.infinity,
            child: PageView.builder(
              itemCount: imagenes.length,
              onPageChanged: (i) => setState(() => _paginaActual = i),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) => _imagen(imagenes[index], estilo),
            ),
          ),
          IgnorePointer(
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _botonCircular(
                    icono: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      _botonCircular(
                        icono: Icons.timeline_rounded,
                        tooltip: context.tr('ver_seguimiento_destino'),
                        onTap: _abrirSeguimiento,
                      ),
                      const SizedBox(width: 6),
                      ValueListenableBuilder(
                        valueListenable: listaFavoritos,
                        builder: (context, favoritos, _) {
                          final esFav = favoritos.any(
                            (e) => e['titulo'] == _lugar.nombre,
                          );
                          return _botonCircular(
                            icono: esFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: esFav ? AppColores.rojoAlerta : Colors.white,
                            onTap: _alternarFavorito,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 38,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final categoria in _lugar.categorias.take(3))
                      _chipCategoria(categoria),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _lugar.nombre.replaceAll('\n', ' '),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 15, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _lugar.distrito,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    if (_lugar.ratingPromedio != null) ...[
                      const Icon(Icons.star_rounded,
                          size: 16, color: Color(0xFFFFC93C)),
                      const SizedBox(width: 3),
                      Text(
                        _lugar.ratingPromedio!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (imagenes.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imagenes.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _paginaActual == index ? 14 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _paginaActual == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagen(String ruta, EstiloCategoria estilo) {
    Widget respaldo() => Container(
      color: estilo.color.withValues(alpha: 0.25),
      child: Center(
        child: Icon(estilo.icono, size: 64, color: Colors.white),
      ),
    );

    if (ruta.startsWith('assets/')) {
      return Image.asset(
        ruta,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => respaldo(),
      );
    }
    return Image.network(
      ruta,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => respaldo(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : respaldo(),
    );
  }

  Widget _botonCircular({
    required IconData icono,
    required VoidCallback onTap,
    Color color = Colors.white,
    String? tooltip,
  }) {
    final boton = Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icono, color: color, size: 23),
        ),
      ),
    );
    return tooltip == null ? boton : Tooltip(message: tooltip, child: boton);
  }

  Widget _chipCategoria(String categoria) {
    final estilo = CategoriasLugar.estilo(categoria);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: estilo.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estilo.icono, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            categoria,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Acciones
  // ------------------------------------------------------------------

  /// Fila de acciones: ver en el mapa y guardar en favoritos.
  Widget _accionesPrincipales() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.turquesaOasis,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _verEnMapa,
                icon: const Icon(Icons.map_rounded, size: 19),
                label: Text(
                  context.tr('ver_en_mapa'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ValueListenableBuilder(
              valueListenable: listaFavoritos,
              builder: (context, favoritos, _) {
                final esFav = favoritos.any(
                  (e) => e['titulo'] == _lugar.nombre,
                );
                return SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColores.rojoAlerta,
                      side: BorderSide(
                        color: AppColores.rojoAlerta.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _alternarFavorito,
                    icon: Icon(
                      esFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                    ),
                    label: Text(
                      esFav
                          ? context.tr('guardado')
                          : context.tr('guardar'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueTexto({
    required String titulo,
    required String cuerpo,
    required Color colorTexto,
    required Color colorTextoSecundario,
    required Color colorTarjeta,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cuerpo,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: colorTextoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recomendacionOficial(Color colorTexto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColores.verdeOasis.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: AppColores.verdeOasis.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: AppColores.verdeOasis, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('recomendacion_oficial'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColores.verdeOasis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _lugar.recomendacionOficial!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: colorTexto,
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

  Widget _avisoAlerta() {
    return ValueListenableBuilder<List<AlertaClima>>(
      valueListenable: _alertasService.alertasNotifier,
      builder: (context, alertas, _) {
        final activas = alertas.where((a) {
          final actividad = a.actividad.replaceAll('\n', ' ').trim().toLowerCase();
          final nombre = _lugar.nombre.replaceAll('\n', ' ').trim().toLowerCase();
          return a.activa &&
              (actividad == nombre ||
                  nombre.contains(actividad) ||
                  actividad.contains(nombre));
        }).toList();

        if (activas.isEmpty) return const SizedBox.shrink();
        final alerta = activas.first;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Material(
            color: alerta.nivelRiesgo.colorFondo,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PantallaDetalleAlerta(alerta: alerta),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: alerta.nivelRiesgo.color,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(alerta.nivelRiesgo.icono,
                        color: alerta.nivelRiesgo.color, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: alerta.nivelRiesgo.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  alerta.nivelRiesgo.etiqueta.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('alerta_climatica'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColores.marronOscuro,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alerta.titulo,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: alerta.nivelRiesgo.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${alerta.motivoCambio.split('.').first}. '
                            '${context.tr('toca_ver_alternativas')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColores.grisTexto),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tarjetaRecomendacionIA(
    Color colorTexto,
    Color colorTextoSecundario,
    Color colorTarjeta,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('recomendacion_para_actividad'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: colorTarjeta,
            borderRadius: BorderRadius.circular(15),
            elevation: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PantallaDetalleDia(
                    tituloActividad: _lugar.nombre,
                    imagenActividad: _lugar.imagenPrincipal,
                    atractivoId: _lugar.esMock ? null : _lugar.id,
                    // El mapa sí reconoce los mocks, así que el zoom funciona
                    // aunque el backend esté caído.
                    idLugar: _lugar.id,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColores.naranjaBoton,
                            Color(0xFFFFB300),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 27),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        context.tr('ver_recomendacion_actividad'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorTexto,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 15, color: colorTextoSecundario),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirSeguimiento() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaSeguimientoDestino(
          nombreDestinoInicial: _lugar.nombre,
        ),
      ),
    );
  }

  Widget _tarjetaSeguimiento(
    Color colorTexto,
    Color colorTextoSecundario,
    Color colorTarjeta,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: colorTarjeta,
        borderRadius: BorderRadius.circular(15),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _abrirSeguimiento,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColores.azulParacas.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timeline_rounded,
                      color: AppColores.azulParacas, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('seguimiento_de')} ${_lugar.distrito}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorTexto,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('historial_cambios_clima'),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorTextoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppColores.naranjaBoton),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _factoresClima(
    Color colorTexto,
    Color colorTextoSecundario,
    Color colorTarjeta,
  ) {
    final temp = _climaActual != null
        ? '${(_climaActual!['temperatura_actual'] as num?)?.round() ?? 22}°C'
        : '--';
    final viento = _climaActual != null
        ? '${(_climaActual!['velocidad_viento'] as num?)?.round() ?? 5} km/h'
        : '--';
    final humedad = _climaActual != null
        ? '${(_climaActual!['humedad'] as num?)?.round() ?? 70}%'
        : '--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('factores_estadisticos'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
              ),
              if (_cargandoClima)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
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
            child: Column(
              children: [
                _FilaFactor(
                  icono: Icons.thermostat_rounded,
                  color: AppColores.naranjaBoton,
                  nombre: context.tr('temperatura'),
                  valor: temp,
                  colorTexto: colorTexto,
                ),
                _separador(colorTextoSecundario),
                _FilaFactor(
                  icono: Icons.air_rounded,
                  color: AppColores.turquesaOasis,
                  nombre: context.tr('viento'),
                  valor: viento,
                  colorTexto: colorTexto,
                ),
                _separador(colorTextoSecundario),
                _FilaFactor(
                  icono: Icons.water_drop_rounded,
                  color: AppColores.azulParacas,
                  nombre: context.tr('humedad'),
                  valor: humedad,
                  colorTexto: colorTexto,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _separador(Color color) => Divider(
    height: 1,
    thickness: 0.5,
    indent: 16,
    endIndent: 16,
    color: color.withValues(alpha: 0.2),
  );
}

class _FilaFactor extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String nombre;
  final String valor;
  final Color colorTexto;

  const _FilaFactor({
    required this.icono,
    required this.color,
    required this.nombre,
    required this.valor,
    required this.colorTexto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: TextStyle(fontSize: 14, color: colorTexto),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
        ],
      ),
    );
  }
}
