import 'dart:async'; // Necesario para el Timer del carrusel

import 'package:flutter/material.dart';

import '../config/tema.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  // Controlador del carrusel
  final PageController _pageController = PageController();
  int _paginaActual = 0;

  // Lista de imágenes del carrusel
  final List<String> _imagenesCarrusel = [
    'assets/images/carrusel_1_huacachina.jpg',
    'assets/images/carrusel_2_vinos.jpg',
    'assets/images/carrusel_3_sandboarding.jpg',
  ];

  Timer? _timerCarrusel;

  @override
  void initState() {
    super.initState();
    // Cambia de imagen cada 4 segundos
    _timerCarrusel = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_paginaActual < _imagenesCarrusel.length - 1) {
        _paginaActual++;
      } else {
        _paginaActual = 0; // Vuelve a la primera
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

  @override
  void dispose() {
    _timerCarrusel?.cancel(); // Limpiar el timer al salir
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: Stack(
        children: [
          // 1. Carrusel de imágenes en la parte superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
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
                // Capa oscura para que el texto se lea
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                // Puntitos indicadores (los 3 puntitos)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Row(
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
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Contenido encima del carrusel
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AppBar manual
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Icon(Icons.menu, color: Colors.white, size: 28),
                        Icon(
                          Icons.notifications_none,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Títulos
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
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
                          style: TextStyle(fontSize: 18, color: Colors.white),
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
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // 👇 Más espacio para bajar la tarjeta
                  const SizedBox(height: 70),

                  // 3. Tarjeta blanca del clima
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
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Ahora en Ica',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  _indicador(true, 'Sol'),
                                  const SizedBox(width: 8),
                                  _indicador(false, 'Nublado'),
                                ],
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
                              const Text(
                                '26°C',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Viento   12 km/h',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColores.grisTexto,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Humedad  48%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColores.grisTexto,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'UV        Alto',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColores.grisTexto,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Botón
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
                        onPressed: () {},
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
        ],
      ),
    ); // <-- Aquí termina el Scaffold SIN la barra inferior
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
