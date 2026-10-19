import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';

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
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

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
                  child: Image.asset(
                    imagenActividad,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.grey[400]);
                    },
                  ),
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
                    'Detalle del Día',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tituloActividad.replaceAll('\n', ' '),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fecha,
                    style: TextStyle(fontSize: 13, color: colorTextoSecundario),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Excelente',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorTexto,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Condiciones ideales para disfrutar esta actividad.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorTextoSecundario,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen del plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
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
                          valor: '28°C',
                          etiqueta: 'Temperatura',
                          colorTexto: colorTexto,
                          colorTextoSecundario: colorTextoSecundario,
                        ),
                        _MiniFactor(
                          icono: Icons.air,
                          valor: '15 km/h',
                          etiqueta: 'Viento',
                          colorTexto: colorTexto,
                          colorTextoSecundario: colorTextoSecundario,
                        ),
                        _MiniFactor(
                          icono: Icons.cloud_outlined,
                          valor: '10%',
                          etiqueta: 'Nubosidad',
                          colorTexto: colorTexto,
                          colorTextoSecundario: colorTextoSecundario,
                        ),
                        _MiniFactor(
                          icono: Icons.water_drop_outlined,
                          valor: '0%',
                          etiqueta: 'Lluvia',
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
                    'Índice de condición',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: 0.92,
                            minHeight: 12,
                            backgroundColor: colorTextoSecundario.withOpacity(
                              0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColores.naranjaBoton,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorTextoSecundario,
                              ),
                            ),
                            Text(
                              '100',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorTextoSecundario,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '92',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColores.naranjaBoton,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Excelente',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
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
          style: TextStyle(fontSize: 10, color: colorTextoSecundario),
        ),
      ],
    );
  }
}
