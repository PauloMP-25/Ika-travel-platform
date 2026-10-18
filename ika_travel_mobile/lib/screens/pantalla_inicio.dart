import 'dart:async';

import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import 'pantalla_detalle_dia.dart';
import 'pantalla_alertas.dart';
import 'pantalla_mas.dart';

class PantallaInicio extends StatefulWidget {
  final WeatherService? weatherService;

  const PantallaInicio({super.key, this.weatherService});

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
  late final WeatherService _weatherService;
  ClimaActualModel? _climaActual;
  bool _cargandoClima = true;

  @override
  void initState() {
    super.initState();
    _weatherService = widget.weatherService ?? WeatherService();
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
    setState(() => _cargandoClima = true);
    final clima = await _weatherService.getClimaActual(destino: 'Ica');
    if (mounted) {
      setState(() {
        _climaActual = clima;
        _cargandoClima = false;
      });
    }
  }

  @override
  void dispose() {
    _timerCarrusel?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  IconData _obtenerIconoClima(String descripcion) {
    final d = descripcion.toLowerCase();
    if (d.contains('lluv') || d.contains('precipitacion')) return Icons.water_drop;
    if (d.contains('viento') || d.contains('paracas')) return Icons.air;
    if (d.contains('nub') || d.contains('cubierto')) return Icons.wb_cloudy;
    return Icons.wb_sunny;
  }

  @override
  Widget build(BuildContext context) {
    final clima = _climaActual;
    final esSol = clima == null || !clima.descripcionClima.toLowerCase().contains('nub');

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: RefreshIndicator(
        onRefresh: _cargarClima,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. CARRUSEL CON IMÁGENES Y TEXTO
              SizedBox(
                height: 380,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _imagenesCarrusel.length,
                      onPageChanged: (index) {
                        setState(() {
                          _paginaActual = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return Image.asset(
                          _imagenesCarrusel[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColores.naranjaBoton,
                              child: const Center(
                                child: Icon(Icons.image, size: 60, color: Colors.white70),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Gradiente oscuro
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),

                    // Contenido encima de la imagen
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            // BARRA SUPERIOR
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Image.asset(
                                      'assets/images/logo_ika.png',
                                      height: 35,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.travel_explore, color: Colors.white, size: 30),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Ika Travel',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const PantallaAlertas()),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.menu, color: Colors.white),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const PantallaMas()),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // TÍTULOS
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

              // 2. PUNTITOS indicadores
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
                          : Colors.grey[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. TARJETA DEL CLIMA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColores.blancoTarjeta,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _cargandoClima && clima == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Ahora en ${clima?.destino ?? "Ica"}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    _indicador(esSol, 'Sol'),
                                    const SizedBox(width: 8),
                                    _indicador(!esSol, 'Nublado'),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  _obtenerIconoClima(clima?.descripcionClima ?? 'Soleado'),
                                  size: 50,
                                  color: Colors.orange,
                                ),
                                Text(
                                  '${clima?.temperaturaActual.round() ?? 26}°C',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Viento   ${clima?.velocidadViento.round() ?? 12} km/h',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColores.grisTexto,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Humedad  ${clima?.humedad.round() ?? 48}%',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColores.grisTexto,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'UV        ${clima?.nivelUv ?? "Alto"}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColores.grisTexto,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (clima != null && clima.isCached) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.offline_bolt, size: 14, color: Colors.amber[800]),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Dato en caché local',
                                      style: TextStyle(fontSize: 11, color: Colors.amber[900]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // 4. BOTÓN
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColores.naranjaBoton,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaDetalleDia(
                            tituloActividad: 'Clima en Ica hoy',
                            imagenActividad:
                                'assets/images/carrusel_1_huacachina.jpg',
                            fecha: 'Recomendación del día',
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicador(bool activo, String texto) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo ? AppColores.naranjaBoton : Colors.grey[300],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, color: AppColores.grisTexto),
        ),
      ],
    );
  }
}
