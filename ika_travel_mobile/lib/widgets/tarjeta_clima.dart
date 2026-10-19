import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class TarjetaClima extends StatefulWidget {
  final String destino;

  const TarjetaClima({super.key, this.destino = 'Ica'});

  @override
  State<TarjetaClima> createState() => _TarjetaClimaState();
}

class _TarjetaClimaState extends State<TarjetaClima> {
  final WeatherService _weatherService = WeatherService();
  late Future<ClimaActualModel> _climaFuture;

  @override
  void initState() {
    super.initState();
    _climaFuture = _weatherService.getClimaActual(destino: widget.destino);
  }

  void _refrescar() {
    setState(() {
      _climaFuture = _weatherService.getClimaActual(destino: widget.destino);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClimaActualModel>(
      future: _climaFuture,
      builder: (context, snapshot) {
        final clima = snapshot.data;
        final bool cargando =
            snapshot.connectionState == ConnectionState.waiting &&
            clima == null;

        final double temp = clima?.temperaturaActual ?? 26.0;
        final double viento = clima?.velocidadViento ?? 12.0;
        final double humedad = clima?.humedad ?? 48.0;
        final String nivelUv = clima?.nivelUv ?? 'Alto';
        final String desc = clima?.descripcionClima ?? 'Soleado';

        return Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ahora en ${widget.destino}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (cargando) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  InkWell(
                    onTap: _refrescar,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColores.naranjaBoton.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColores.naranjaBoton,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(
                    Icons.wb_sunny_rounded,
                    size: 52,
                    color: Colors.orange,
                  ),
                  Text(
                    '${temp.toStringAsFixed(0)}°C',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metricRow('Viento', '${viento.toStringAsFixed(0)} km/h'),
                      const SizedBox(height: 3),
                      _metricRow('Humedad', '${humedad.toStringAsFixed(0)}%'),
                      const SizedBox(height: 3),
                      _metricRow('UV', nivelUv),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColores.grisTexto),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
