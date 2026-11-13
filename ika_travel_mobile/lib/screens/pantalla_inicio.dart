import 'dart:async';

import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../config/traducciones_scope.dart';
import '../services/alertas_service.dart';
import '../services/weather_service.dart';
import 'pantalla_detalle_dia.dart';
import 'pantalla_alertas.dart';
import 'pantalla_mas.dart';
import 'pantalla_planer.dart';
import 'pantalla_prestadores.dart';
import 'pantalla_seguimiento_destino.dart';
import 'pantalla_sos.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  final PageController _pageController = PageController();
  int _paginaActual = 0;

  final List<String> _imagenesCarrusel = [
    'assets/images/carrusel_1_huacachina.jpg',
    'assets/images/carrusel_2_vinos.jpg',
    'assets/images/carrusel_3_sandboarding.jpg',
  ];

  Timer? _timerCarrusel;
  Map<String, dynamic>? _clima;
  bool _cargandoClima = true;

  @override
  void initState() {
    super.initState();
    _cargarClima();

    _timerCarrusel = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_paginaActual < _imagenesCarrusel.length - 1) {
        _paginaActual++;
      } else {
        _paginaActual = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _paginaActual,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _cargarClima() async {
    final weather = WeatherService();
    final data = await weather.obtenerClimaActual();
    setState(() {
      _clima = data;
      _cargandoClima = false;
    });
  }

  @override
  void dispose() {
    _timerCarrusel?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double alturaCarrusel = (MediaQuery.of(context).size.height * 0.48)
        .clamp(340.0, 480.0);

    final colorFondoApp = TemaApp.fondo(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return Scaffold(
      backgroundColor: colorFondoApp,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              child: SizedBox(
                height: alturaCarrusel,
                width: double.infinity,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _imagenesCarrusel.length,
                      onPageChanged: (index) {
                        setState(() => _paginaActual = index);
                      },
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(_imagenesCarrusel[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ICONOS SUPERIORES
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PantallaMas(),
                                      ),
                                    );
                                  },
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const PantallaSos(),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD32F2F),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.shield,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'SOS',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Botón de Alertas
                                    ValueListenableBuilder(
                                      valueListenable:
                                          AlertasService().alertasNotifier,
                                      builder: (context, _, _) {
                                        final activas = AlertasService()
                                            .alertasActivas
                                            .length;
                                        return Stack(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.notifications_none,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const PantallaAlertas(),
                                                  ),
                                                );
                                              },
                                            ),
                                            if (activas > 0)
                                              Positioned(
                                                right: 8,
                                                top: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFE53935,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 16,
                                                        minHeight: 16,
                                                      ),
                                                  child: Text(
                                                    '$activas',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            // TEXTOS DEL CARRUSEL (Sin const)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'ICA',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    context.tr('turismo_clima'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    context.tr('que_planes_hoy'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.tr('ayudamos_elegir'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _imagenesCarrusel.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _paginaActual == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _paginaActual == index
                        ? AppColores.naranjaBoton
                        : colorTextoSecundario.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // TARJETA DEL CLIMA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorTarjeta,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _cargandoClima
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                context.tr('ahora_en_ica'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorTexto,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _clima != null
                                      ? (_clima!['descripcion_clima'] ??
                                            'Desconocido')
                                      : 'Soleado',
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorTextoSecundario,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Builder(
                                builder: (context) {
                                  final hora = DateTime.now().hour;
                                  final esNoche = hora < 6 || hora >= 18;
                                  final desc = (_clima != null ? _clima!['descripcion_clima'] ?? '' : '').toString().toLowerCase();
                                  IconData icono = esNoche ? Icons.nightlight_round : Icons.wb_sunny;
                                  Color color = esNoche ? const Color(0xFFFFD54F) : Colors.orange;
                                  if (desc.contains('lluv')) {
                                    icono = Icons.grain;
                                    color = Colors.lightBlue;
                                  } else if (desc.contains('nub')) {
                                    icono = esNoche ? Icons.nights_stay : Icons.cloud;
                                    color = esNoche ? const Color(0xFF90CAF9) : Colors.blueGrey;
                                  }
                                  return Icon(
                                    icono,
                                    size: 55,
                                    color: color,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _clima != null
                                        ? '${(_clima!['temperatura_actual'] as num).round()}°C'
                                        : '26°C',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: colorTexto,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${context.tr('viento')}  ${_clima != null ? (_clima!['velocidad_viento'] as num).round() : '12'} km/h',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorTextoSecundario,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${context.tr('humedad')}  ${_clima != null ? (_clima!['humedad'] as num).round() : '48'}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorTextoSecundario,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${context.tr('uv')}  ${_clima != null ? (_clima!['indice_uv'] as num).round() : 'Alto'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorTextoSecundario,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: colorTextoSecundario.withOpacity(0.2),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PantallaSeguimientoDestino(),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.timeline,
                                  size: 18,
                                  color: AppColores.naranjaBoton,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    context.tr('seguimiento_destinos'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorTexto,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: AppColores.naranjaBoton,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),

            // CTA principal: recomendación del día
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.naranjaBoton,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PantallaDetalleDia(
                          tituloActividad: 'Clima en Ica hoy',
                          imagenActividad:
                              'assets/images/carrusel_1_huacachina.jpg',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: Text(
                    context.tr('ver_recomendacion'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            // Accesos rápidos (cuadrícula compacta en vez de banners apilados)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.tr('accesos_rapidos'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _tileAcceso(
                    icono: Icons.route,
                    etiqueta: context.tr('acc_planificar'),
                    color: AppColores.naranjaBoton,
                    colorTexto: colorTexto,
                    colorTarjeta: colorTarjeta,
                    destino: const PantallaPlaner(),
                  ),
                  const SizedBox(width: 12),
                  _tileAcceso(
                    icono: Icons.verified_user_rounded,
                    etiqueta: context.tr('acc_servicios'),
                    color: AppColores.turquesaOasis,
                    colorTexto: colorTexto,
                    colorTarjeta: colorTarjeta,
                    destino: const PantallaPrestadores(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _tileAcceso(
                    icono: Icons.notifications_active_rounded,
                    etiqueta: context.tr('acc_alertas'),
                    color: AppColores.azulParacas,
                    colorTexto: colorTexto,
                    colorTarjeta: colorTarjeta,
                    destino: const PantallaAlertas(),
                  ),
                  const SizedBox(width: 12),
                  _tileAcceso(
                    icono: Icons.shield_rounded,
                    etiqueta: context.tr('acc_sos'),
                    color: AppColores.rojoAlerta,
                    colorTexto: colorTexto,
                    colorTarjeta: colorTarjeta,
                    destino: const PantallaSos(),
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

  Widget _tileAcceso({
    required IconData icono,
    required String etiqueta,
    required Color color,
    required Color colorTexto,
    required Color colorTarjeta,
    required Widget destino,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destino),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: colorTarjeta,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorTexto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
