import 'package:flutter/material.dart';

import '../config/favoritos_manager.dart';
import '../config/tema.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class PantallaAlertas extends StatefulWidget {
  const PantallaAlertas({super.key});

  @override
  State<PantallaAlertas> createState() => _PantallaAlertasState();
}

class _PantallaAlertasState extends State<PantallaAlertas> {
  int _opcionSeleccionada = 0; // 0 = Alertas Activas, 1 = Historial
  final WeatherService _weatherService = WeatherService();
  late Future<List<AlertaClimaModel>> _alertasFuture;

  @override
  void initState() {
    super.initState();
    _alertasFuture = _weatherService.getAlertasActivas();
  }

  void _recargar() {
    setState(() {
      _alertasFuture = _weatherService.getAlertasActivas();
    });
  }

  // Historial de alertas de ejemplo
  final List<Map<String, dynamic>> _historial = [
    {
      'titulo': 'Viento Paracas en la costa',
      'fecha': 'Ayer, 15:00',
      'descripcion': 'Se registraron ráfagas de 35 km/h en la Bahía de Paracas.',
      'icono': Icons.air_rounded,
      'colorIcono': Colors.teal,
    },
    {
      'titulo': 'Cielo despejado en Ica',
      'fecha': 'Hace 2 días',
      'descripcion': 'Condiciones ideales registradas para turismo y viñedos.',
      'icono': Icons.wb_sunny_rounded,
      'colorIcono': Colors.orange,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColores.marronOscuro,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Alertas y Avisos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColores.marronOscuro,
                      size: 28,
                    ),
                    onPressed: _recargar,
                  ),
                ],
              ),
            ),

            // Selector de pestañas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _botonToggle('Alertas Activas', 0),
                    _botonToggle('Historial', 1),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Contenido según pestaña
            Expanded(
              child: _opcionSeleccionada == 0
                  ? _buildAlertasActivas()
                  : _buildHistorial(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertasActivas() {
    return FutureBuilder<List<AlertaClimaModel>>(
      future: _alertasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColores.naranjaBoton),
          );
        }

        final alertas = snapshot.data ?? [];
        if (alertas.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  color: Colors.green,
                ),
                SizedBox(height: 12),
                Text(
                  'No hay alertas meteorológicas críticas.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColores.marronOscuro,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Las condiciones en el departamento de Ica son favorables.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColores.grisTexto, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColores.naranjaBoton,
          onRefresh: () async => _recargar(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: alertas.length,
            itemBuilder: (context, index) {
              final alerta = alertas[index];
              return _tarjetaAlertaApi(alerta);
            },
          ),
        );
      },
    );
  }

  Widget _tarjetaAlertaApi(AlertaClimaModel alerta) {
    Color colorSeveridad = Colors.orange;
    IconData icono = Icons.warning_amber_rounded;

    if (alerta.severity.toUpperCase() == 'HIGH' ||
        alerta.severity.toUpperCase() == 'EXTREMA') {
      colorSeveridad = Colors.redAccent;
      icono = Icons.error_outline_rounded;
    } else if (alerta.code.contains('VIENTO')) {
      colorSeveridad = Colors.teal;
      icono = Icons.air_rounded;
    } else if (alerta.code.contains('UV')) {
      colorSeveridad = Colors.deepOrange;
      icono = Icons.wb_sunny_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: colorSeveridad, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorSeveridad.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: colorSeveridad, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      alerta.zone,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorSeveridad.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        alerta.severity,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorSeveridad,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alerta.message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Válido hasta: ${alerta.endsAt.hour.toString().padLeft(2, '0')}:${alerta.endsAt.minute.toString().padLeft(2, '0')} hrs',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColores.grisTexto,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorial() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _historial.length,
      itemBuilder: (context, index) {
        final alerta = _historial[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(alerta['icono'], color: alerta['colorIcono'], size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alerta['titulo'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                    Text(
                      alerta['fecha'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.grisTexto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alerta['descripcion'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _botonToggle(String texto, int index) {
    final bool activo = _opcionSeleccionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _opcionSeleccionada = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: activo ? AppColores.marronOscuro : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                color: activo ? Colors.white : AppColores.grisTexto,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
