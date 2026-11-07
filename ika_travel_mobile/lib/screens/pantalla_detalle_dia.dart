import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/colores_tema.dart';
import '../config/navegacion_service.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../services/weather_service.dart';

class PantallaDetalleDia extends StatefulWidget {
  final String tituloActividad;
  final String imagenActividad;
  final String? fecha;
  final String? atractivoId; // NUEVO

  const PantallaDetalleDia({
    super.key,
    required this.tituloActividad,
    required this.imagenActividad,
    this.fecha,
    this.atractivoId, // NUEVO
  });

  @override
  State<PantallaDetalleDia> createState() => _PantallaDetalleDiaState();
}

class _PantallaDetalleDiaState extends State<PantallaDetalleDia> {
  final WeatherService _weatherService = WeatherService();

  Map<String, dynamic>? _climaActual;
  bool _cargando = true;

  String? _textoRecomendacionIA;
  String? _nombreAtractivo;
  double _scoreRecomendacion = 0.0;
  String _nivelRecomendacion = '';
  List<dynamic> _consejosIA = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosClima();
  }

  Future<void> _cargarDatosClima() async {
    // 👇 NUEVO: verificar si llega el atractivoId
    debugPrint('🔍 DEBUG: atractivoId recibido = ${widget.atractivoId}');

    try {
      final clima = await _weatherService.obtenerClimaActual();
      final pron = await _weatherService.obtenerPronostico();

      // NUEVO: si hay atractivoId, usa el endpoint específico
      final recIA = widget.atractivoId != null
          ? await _weatherService.obtenerRecomendacionPorAtractivo(
              widget.atractivoId!,
            )
          : await _weatherService.obtenerRecomendacionDelDia();

      // 👇 NUEVO: verificar qué devuelve el backend
      debugPrint(
        '🔍 DEBUG: atractivo_nombre devuelto = ${recIA?['atractivo_nombre']}',
      );

      if (mounted) {
        setState(() {
          _climaActual = clima;
          if (recIA != null) {
            _textoRecomendacionIA = recIA['recommendation_text'] as String?;
            _consejosIA = (recIA['consejos'] as List<dynamic>?) ?? [];
            _nombreAtractivo = recIA['atractivo_nombre'] as String?;
            _scoreRecomendacion = (recIA['score'] as num?)?.toDouble() ?? 0.0;
            _nivelRecomendacion = (recIA['nivel'] as String?) ?? '';
          }
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  String _obtenerFechaFormateada(BuildContext context) {
    if (widget.fecha != null && widget.fecha!.isNotEmpty) {
      return widget.fecha!;
    }
    final ahora = DateTime.now();
    final diaSemana = DateFormat(
      'EEEE',
      context.locale.languageCode,
    ).format(ahora);
    final mes = DateFormat('MMMM', context.locale.languageCode).format(ahora);
    final hora = DateFormat('hh:mm a').format(ahora);
    final diaCapitalizado = diaSemana[0].toUpperCase() + diaSemana.substring(1);
    final mesCapitalizado = mes[0].toUpperCase() + mes.substring(1);

    return '$diaCapitalizado, ${ahora.day} ${context.tr('de')} $mesCapitalizado ${context.tr('de')} ${ahora.year} - $hora';
  }

  Widget _buildImagenCabecera() {
    if (widget.imagenActividad.startsWith('assets/')) {
      return Image.asset(
        widget.imagenActividad,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/carrusel_1_huacachina.jpg',
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.network(
      widget.imagenActividad,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/carrusel_1_huacachina.jpg',
        fit: BoxFit.cover,
      ),
    );
  }

  Color _colorScore(double score) {
    if (score >= 0.7) return const Color(0xFF2E7D32);
    if (score >= 0.4) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    final temp = _climaActual != null
        ? '${(_climaActual!['temperatura_actual'] as num?)?.round() ?? 22}°C'
        : '22°C';
    final viento = _climaActual != null
        ? '${(_climaActual!['velocidad_viento'] as num?)?.round() ?? 5} km/h'
        : '5 km/h';
    final humedad = _climaActual != null
        ? '${(_climaActual!['humedad'] as num?)?.round() ?? 70}%'
        : '70%';
    final lluvia = _climaActual != null
        ? '${(_climaActual!['probabilidad_precipitacion'] as num?)?.round() ?? 10}%'
        : '10%';
    final uv = _climaActual != null
        ? '${(_climaActual!['indice_uv'] as num?)?.round() ?? 0}'
        : '0';
    final descripcion = _climaActual != null
        ? (_climaActual!['descripcion_clima'] ?? context.tr('cielo_claro'))
        : context.tr('cielo_despejado');

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: _buildImagenCabecera(),
                ),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('detalle_dia'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.tituloActividad.replaceAll('\n', ' '),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _obtenerFechaFormateada(context),
                    style: TextStyle(
                      fontSize: 13,
                      color: colorTextoSecundario,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
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
                child: _buildTarjetaMomento(
                  context,
                  colorTexto,
                  colorTextoSecundario,
                  temp,
                  humedad,
                  uv,
                  descripcion,
                ),
              ),
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('datos_tiempo_real'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorTexto,
                        ),
                      ),
                      if (_cargando)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniFactor(
                          icono: Icons.thermostat,
                          valor: temp,
                          etiqueta: context.tr('temperatura'),
                          colorTexto: colorTexto,
                          colorTextoSecundario: colorTextoSecundario,
                        ),
                        _MiniFactor(
                          icono: Icons.air,
                          valor: viento,
                          etiqueta: context.tr('viento'),
                          colorTexto: colorTexto,
                          colorTextoSecundario: colorTextoSecundario,
                        ),
                        _MiniFactor(
                          icono: Icons.water_drop_outlined,
                          valor: humedad,
                          etiqueta: context.tr('humedad'),
                          colorTexto: colorTexto,
                          colorTextoSecundario: colorTextoSecundario,
                        ),
                        _MiniFactor(
                          icono: Icons.umbrella_outlined,
                          valor: lluvia,
                          etiqueta: context.tr('lluvia'),
                          colorTexto: colorTexto,
                          colorTextoSecundario: colorTextoSecundario,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('tu_plan_ideal_hoy'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorTarjeta,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _colorScore(_scoreRecomendacion)
                            .withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColores.naranjaBoton.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: AppColores.naranjaBoton,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.tr('recomendacion_ia_titulo'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorTextoSecundario,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _nombreAtractivo ?? '...',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: colorTexto,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _colorScore(_scoreRecomendacion)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _colorScore(_scoreRecomendacion),
                                ),
                              ),
                              child: Text(
                                '${(_scoreRecomendacion * 100).toStringAsFixed(0)}/100',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _colorScore(_scoreRecomendacion),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_nivelRecomendacion.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _nivelRecomendacion.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _colorScore(_scoreRecomendacion),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: colorTextoSecundario.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _textoRecomendacionIA ??
                              '${context.tr('recomendacion_ia_default_1')} $temp ${context.tr('y_humedad_de')} $humedad, ${context.tr('recomendacion_ia_default_2')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorTexto,
                            height: 1.5,
                          ),
                        ),
                        if (_consejosIA.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ..._consejosIA.map(
                            (consejo) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppColores.naranjaBoton,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      consejo.toString(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorTextoSecundario,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColores.naranjaBoton,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.explore_outlined),
                            label: Text(
                              context.tr('ver_en_mapa'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              NavegacionService.irAMapa(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaMomento(
    BuildContext context,
    Color colorTexto,
    Color colorTextoSecundario,
    String temp,
    String humedad,
    String uv,
    String descripcion,
  ) {
    final horaActual = DateTime.now().hour;
    final esNoche = horaActual < 6 || horaActual >= 18;
    final iconoMomento = esNoche ? Icons.nights_stay : Icons.wb_sunny;
    final tituloMomento = esNoche
        ? context.tr('condicion_nocturna')
        : context.tr('condicion_diurna');
    final descMomento = esNoche
        ? '${context.tr('estado_actual')} $descripcion. ${context.tr('temp_templada')} ($temp, ${context.tr('humedad')} $humedad).'
        : '${context.tr('estado_actual')} $descripcion. ${context.tr('temp_de')} $temp ${context.tr('con_radiacion')} $uv.';

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColores.naranjaBoton.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(iconoMomento, color: AppColores.naranjaBoton, size: 28),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tituloMomento,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorTexto,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _cargando ? context.tr('consultando_sensores') : descMomento,
                style: TextStyle(fontSize: 12, color: colorTextoSecundario),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniFactor extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color colorTexto;
  final Color colorTextoSecundario;

  const _MiniFactor({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    required this.colorTexto,
    required this.colorTextoSecundario,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: AppColores.naranjaBoton, size: 24),
        const SizedBox(height: 6),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorTexto,
          ),
        ),
        Text(
          etiqueta,
          style: TextStyle(fontSize: 11, color: colorTextoSecundario),
        ),
      ],
    );
  }
}
