import 'package:flutter/material.dart';

import '../config/tema.dart';

class PantallaDetalle extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final List<String> imagenes;

  const PantallaDetalle({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.imagenes,
  });

  @override
  State<PantallaDetalle> createState() => _PantallaDetalleState();
}

class _PantallaDetalleState extends State<PantallaDetalle> {
  bool _esFavorito = false;
  int _paginaActual = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Imagen con esquinas inferiores redondeadas + carrusel
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              child: Stack(
                children: [
                  // Carrusel de imágenes
                  SizedBox(
                    height: 320,
                    width: double.infinity,
                    // 👇 GestureDetector captura los gestos horizontales
                    // para que el SingleChildScrollView no los intercepte
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        // Solo captura el gesto, no hace nada
                      },
                      child: PageView.builder(
                        itemCount: widget.imagenes.length,
                        onPageChanged: (index) {
                          setState(() => _paginaActual = index);
                        },
                        // 👇 Mejoras de física y comportamiento
                        physics: const BouncingScrollPhysics(),
                        padEnds: true,
                        itemBuilder: (context, index) {
                          return Image.asset(
                            widget.imagenes[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[400],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Capa oscura para que el texto se lea
                  IgnorePointer(
                    child: Container(
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.5),
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Botones de arriba (atrás y favorito)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          IconButton(
                            icon: Icon(
                              _esFavorito
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                _esFavorito = !_esFavorito;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Título y subtítulo
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titulo.replaceAll('\n', ' '),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitulo,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Puntitos indicadores
                  Positioned(
                    bottom: 15,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.imagenes.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _paginaActual == index ? 12 : 8,
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

            const SizedBox(height: 20),

            // 2. Tarjeta "Recomendación para hoy"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recomendación para hoy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 55,
                          height: 55,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF3E0),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('😊', style: TextStyle(fontSize: 30)),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Excelente',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColores.marronOscuro,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Condiciones ideales para disfrutar estas actividades.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColores.grisTexto,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 3. Factores estadísticos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Factores estadísticos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: const [
                        _FilaFactor(
                          icono: Icons.thermostat,
                          nombre: 'Temperatura',
                          valor: '28°C',
                        ),
                        Divider(height: 1, thickness: 0.5),
                        _FilaFactor(
                          icono: Icons.air,
                          nombre: 'Viento',
                          valor: '15 km/h',
                        ),
                        Divider(height: 1, thickness: 0.5),
                        _FilaFactor(
                          icono: Icons.cloud_outlined,
                          nombre: 'Nubosidad',
                          valor: '10%',
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
}

// Widget para cada fila de factor estadístico
class _FilaFactor extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final String valor;

  const _FilaFactor({
    required this.icono,
    required this.nombre,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, color: AppColores.marronOscuro, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(
                fontSize: 14,
                color: AppColores.marronOscuro,
              ),
            ),
          ),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColores.marronOscuro,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppColores.grisTexto,
          ),
        ],
      ),
    );
  }
}
