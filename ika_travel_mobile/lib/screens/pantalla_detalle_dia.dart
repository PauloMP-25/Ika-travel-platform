import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../services/api_service.dart';
import '../services/weather_service.dart';

class PantallaDetalleDia extends StatefulWidget {
  final String idActividad;
  final String tituloActividad;
  final String imagenActividad;
  final String fecha;

  const PantallaDetalleDia({
    super.key,
    required this.idActividad,
    required this.tituloActividad,
    required this.imagenActividad,
    required this.fecha,
  });

  @override
  State<PantallaDetalleDia> createState() => _PantallaDetalleDiaState();
}

class _PantallaDetalleDiaState extends State<PantallaDetalleDia> {
  Map<String, dynamic>? _clima;
  Map<String, dynamic>? _recomendacionIA;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final api = ApiService();
    final weather = WeatherService();

    final dataClima = await weather.obtenerClimaActual();
    final recomendaciones = await api.obtenerRecomendacionesIA();
    final miRecomendacion = recomendaciones?[widget.idActividad];

    setState(() {
      _clima = dataClima;
      _recomendacionIA = miRecomendacion;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    final score = _recomendacionIA?['score'] ?? 0.92;
    final nivel = _recomendacionIA?['nivel'] ?? 'Excelente';
    final textoRecomendacion =
        _recomendacionIA?['recommendation_text'] ?? 'Cargando recomendación...';

    final temp = _clima != null
        ? '${(_clima!['temperatura_actual'] as num).round()}°C'
        : '--';
    final viento = _clima != null
        ? '${(_clima!['velocidad_viento'] as num).round()} km/h'
        : '--';
    final humedad = _clima != null
        ? '${(_clima!['humedad'] as num).round()}%'
        : '--';
    final lluvia = _clima != null
        ? '${(_clima!['probabilidad_precipitacion'] as num).round()}%'
        : '--';

    final indice = (score * 100).round();

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: Image.network(
                          widget.imagenActividad,
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
                              Colors.black.withOpacity(0.5),
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
                          widget.tituloActividad.replaceAll('\n', ' '),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorTexto,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.fecha,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorTextoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 👇 TARJETA CON CARITA FELIZ 😊
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorTarjeta,
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
                              child: Text(
                                '😊',
                                style: TextStyle(fontSize: 28),
                              ), // 👈 Carita feliz
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nivel.toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorTexto,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  textoRecomendacion,
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
                                valor: temp,
                                etiqueta: 'Temperatura',
                                colorTexto: colorTexto,
                                colorTextoSecundario: colorTextoSecundario,
                              ),
                              _MiniFactor(
                                icono: Icons.air,
                                valor: viento,
                                etiqueta: 'Viento',
                                colorTexto: colorTexto,
                                colorTextoSecundario: colorTextoSecundario,
                              ),
                              _MiniFactor(
                                icono: Icons.cloud_outlined,
                                valor: humedad,
                                etiqueta: 'Humedad',
                                colorTexto: colorTexto,
                                colorTextoSecundario: colorTextoSecundario,
                              ),
                              _MiniFactor(
                                icono: Icons.water_drop_outlined,
                                valor: lluvia,
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

                  // 👇 ÍNDICE CALCULADO POR LA IA
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
                                  value: score,
                                  minHeight: 12,
                                  backgroundColor: colorTextoSecundario
                                      .withOpacity(0.2),
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
                                  Text(
                                    '$indice',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: AppColores.naranjaBoton,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    nivel.toString().toUpperCase(),
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
