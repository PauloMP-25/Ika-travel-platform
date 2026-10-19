import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class PantallaDetalleDia extends StatefulWidget {
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
  State<PantallaDetalleDia> createState() => _PantallaDetalleDiaState();
}

class _PantallaDetalleDiaState extends State<PantallaDetalleDia> {
  final WeatherService _weatherService = WeatherService();
  late Future<List<dynamic>> _datosFuture;

  @override
  void initState() {
    super.initState();
    _datosFuture = Future.wait([
      _weatherService.getClimaActual(),
      _weatherService.getRecomendaciones(),
    ]);
  }

  void _refrescar() {
    setState(() {
      _datosFuture = Future.wait([
        _weatherService.getClimaActual(),
        _weatherService.getRecomendaciones(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _datosFuture,
          builder: (context, snapshot) {
            final clima = snapshot.data != null
                ? snapshot.data![0] as ClimaActualModel
                : null;
            final recomendaciones = snapshot.data != null
                ? snapshot.data![1] as List<RecomendacionClimaModel>
                : <RecomendacionClimaModel>[];

            final primeraRecomendacion = recomendaciones.isNotEmpty
                ? recomendaciones.first
                : const RecomendacionClimaModel(
                    actividad: 'Turismo en Ica',
                    score: 0.92,
                    nivel: 'ideal',
                    justificacion:
                        'Condiciones de sol y temperatura ideales para paseos al aire libre.',
                    mejorHorario: '15:30 - 18:30',
                    precauciones: [
                      'Protector solar factor 50+',
                      'Lentes oscuros para arena',
                    ],
                  );

            final double scoreNormalizado =
                (primeraRecomendacion.score <= 1.0)
                    ? primeraRecomendacion.score
                    : primeraRecomendacion.score / 100.0;
            final int scoreEntero = (scoreNormalizado * 100).round();

            final tempStr = clima != null
                ? '${clima.temperaturaActual.toStringAsFixed(0)}°C'
                : '26°C';
            final vientoStr = clima != null
                ? '${clima.velocidadViento.toStringAsFixed(0)} km/h'
                : '12 km/h';
            final humedadStr = clima != null
                ? '${clima.humedad.toStringAsFixed(0)}%'
                : '48%';
            final lluviaStr = clima != null
                ? '${clima.probabilidadPrecipitacion.toStringAsFixed(0)}%'
                : '0%';

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Imagen cabecera con botón volver
                  Stack(
                    children: [
                      Image.asset(
                        widget.imagenActividad,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: 250,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 50),
                        ),
                      ),
                      Positioned(
                        top: 15,
                        left: 15,
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColores.marronOscuro,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 15,
                        right: 15,
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          child: IconButton(
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: AppColores.marronOscuro,
                            ),
                            onPressed: _refrescar,
                          ),
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
                        Text(
                          widget.tituloActividad,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColores.marronOscuro,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.fecha,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColores.grisTexto,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Recomendación generada por IA (Gemini)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border(
                          left: BorderSide(
                            color: AppColores.naranjaBoton,
                            width: 4,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: AppColores.naranjaBoton,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Recomendación Inteligente (Gemini AI)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColores.naranjaBoton,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            primeraRecomendacion.justificacion,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          if (primeraRecomendacion.mejorHorario != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: AppColores.grisTexto,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Mejor horario: ${primeraRecomendacion.mejorHorario}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColores.marronOscuro,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (primeraRecomendacion.precauciones.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: primeraRecomendacion.precauciones
                                  .map(
                                    (p) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        p,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.brown,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Resumen de variables climáticas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Variables meteorológicas del día',
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
                            children: [
                              _MiniFactor(
                                icono: Icons.thermostat,
                                valor: tempStr,
                                etiqueta: 'Temperatura',
                              ),
                              _MiniFactor(
                                icono: Icons.air,
                                valor: vientoStr,
                                etiqueta: 'Viento',
                              ),
                              _MiniFactor(
                                icono: Icons.water_drop_outlined,
                                valor: humedadStr,
                                etiqueta: 'Humedad',
                              ),
                              _MiniFactor(
                                icono: Icons.cloud_outlined,
                                valor: lluviaStr,
                                etiqueta: 'Lluvia',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Índice de recomendación
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Índice de idoneidad climática',
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: scoreNormalizado,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey[200],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    AppColores.naranjaBoton,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                children: [
                                  Text(
                                    '$scoreEntero',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: AppColores.naranjaBoton,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    primeraRecomendacion.nivel.toUpperCase(),
                                    style: const TextStyle(
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
            );
          },
        ),
      ),
    );
  }
}

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
