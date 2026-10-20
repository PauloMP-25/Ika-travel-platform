import 'dart:async';

import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../services/alertas_service.dart';
import '../services/weather_service.dart';
import 'pantalla_detalle_dia.dart';
import 'pantalla_alertas.dart';
import 'pantalla_mas.dart';
import 'pantalla_planer.dart';
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
    final double alturaCarrusel = (MediaQuery.of(context).size.height * 0.48).clamp(340.0, 480.0);

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
                            // ICONOS SUPERIORES CONECTADOS
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
                                          borderRadius:
                                              BorderRadius.circular(20),
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
                                    // Botón de Alertas (Campana con Badge Reactivo)
                                    ValueListenableBuilder(
                                  valueListenable:
                                      AlertasService().alertasNotifier,
                                  builder: (context, _, _) {
                                    final activas =
                                        AlertasService().alertasActivas.length;
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
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFE53935),
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
                                                  fontWeight: FontWeight.bold,
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
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'ICA',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    'Turismo y Clima',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 15),
                                  Text(
                                    '¿Qué planes tienes hoy?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Te ayudamos a elegir el mejor plan según el clima.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
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
            // 3. TARJETA DEL CLIMA CON MONITOREO DIRECTO
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ahora en Ica',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorTexto,
                                ),
                              ),
                              Text(
                                _clima != null
                                    ? (_clima!['descripcion_clima'] ??
                                          'Desconocido')
                                    : 'Soleado',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorTextoSecundario,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(
                                Icons.wb_sunny,
                                size: 55,
                                color: Colors.orange,
                              ),
                              // 👇 REDONDEAMOS LA TEMPERATURA
                              Text(
                                _clima != null
                                    ? '${(_clima!['temperatura_actual'] as num).round()}°C'
                                    : '26°C',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: colorTexto,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Viento   ${_clima != null ? (_clima!['velocidad_viento'] as num).round() : '12'} km/h',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorTextoSecundario,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Humedad  ${_clima != null ? (_clima!['humedad'] as num).round() : '48'}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorTextoSecundario,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'UV        ${_clima != null ? (_clima!['indice_uv'] as num).round() : 'Alto'}',
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
                          Divider(height: 1, thickness: 0.5, color: colorTextoSecundario.withOpacity(0.2)),
                          const SizedBox(height: 10),
                          // Acceso a Seguimiento de Destino (Req 14)
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timeline,
                                      size: 18,
                                      color: AppColores.naranjaBoton,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Seguimiento de destinos turísticos',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colorTexto,
                                      ),
                                    ),
                                  ],
                                ),
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
            const SizedBox(height: 20),
            // 4. BANNER PLANIFICADOR DE VIAJES
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PantallaPlaner(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A3B32), Color(0xFF6D5547)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A3B32).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFD98E3D),
                        child: Icon(
                          Icons.route,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Planificar mi Viaje',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rutas por destinos con distancia y tiempo estimados',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 5. BOTÓN RECOMENDACIÓN DEL DÍA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.naranjaBoton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
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
                          fecha: 'Sábado, 17 de octubre de 2026',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Ver recomendación del día',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 5. BANNER ASISTENCIA Y SOS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PantallaSos(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFE53935).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFFFEBEE),
                        child: Icon(
                          Icons.shield,
                          color: Color(0xFFD32F2F),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asistencia y Emergencia SOS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColores.marronOscuro,
                              ),
                            ),
                            Text(
                              'Alerta rápida y contacto de confianza en Ica',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColores.grisTexto,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: AppColores.grisTexto,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
