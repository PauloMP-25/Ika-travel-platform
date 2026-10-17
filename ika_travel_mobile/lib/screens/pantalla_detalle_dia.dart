import 'package:flutter/material.dart';

import '../config/tema.dart';

class PantallaDetalleDia extends StatelessWidget {
  final String tituloActividad;
  final String imagenActividad;
  final String fecha;

  const PantallaDetalleDia({
    super.key,
    required this.tituloActividad,
    required this.imagenActividad,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Imagen de la actividad con botón de atrás
            Stack(
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Image.asset(
                    imagenActividad,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.grey[400]);
                    },
                  ),
                ),
                // Degradado para que se lea el botón
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Botón de atrás
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

            // 2. Título y fecha
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalle del Día',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tituloActividad.replaceAll('\n', ' '),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fecha,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColores.grisTexto,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. Tarjeta "Excelente"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
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
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF3E0),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('😊', style: TextStyle(fontSize: 28)),
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
                            'Condiciones ideales para disfrutar esta actividad.',
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
            ),

            const SizedBox(height: 25),

            // 4. Resumen del plan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen del plan',
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
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _MiniFactor(
                          icono: Icons.thermostat,
                          valor: '28°C',
                          etiqueta: 'Temperatura',
                        ),
                        _MiniFactor(
                          icono: Icons.air,
                          valor: '15 km/h',
                          etiqueta: 'Viento',
                        ),
                        _MiniFactor(
                          icono: Icons.cloud_outlined,
                          valor: '10%',
                          etiqueta: 'Nubosidad',
                        ),
                        _MiniFactor(
                          icono: Icons.water_drop_outlined,
                          valor: '0%',
                          etiqueta: 'Lluvia',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 5. Índice de condición
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Índice de condición',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
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
                      children: [
                        // Barra de progreso
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: 0.92, // 92%
                            minHeight: 12,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColores.naranjaBoton,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              '0',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColores.grisTexto,
                              ),
                            ),
                            Text(
                              '100',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColores.grisTexto,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              '92',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColores.naranjaBoton,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Excelente',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColores.marronOscuro,
                              ),
                            ),
                          ],
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

// Widget para cada mini factor del resumen
class _MiniFactor extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const _MiniFactor({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: AppColores.naranjaBoton, size: 24),
        const SizedBox(height: 6),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColores.marronOscuro,
          ),
        ),
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 10, color: AppColores.grisTexto),
        ),
      ],
    );
  }
}
