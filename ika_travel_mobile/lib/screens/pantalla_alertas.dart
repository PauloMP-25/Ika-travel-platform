import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/favoritos_manager.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class PantallaAlertas extends StatefulWidget {
  final WeatherService? weatherService;

  const PantallaAlertas({super.key, this.weatherService});

  @override
  State<PantallaAlertas> createState() => _PantallaAlertasState();
}

class _PantallaAlertasState extends State<PantallaAlertas> {
  int _opcionSeleccionada = 0; // 0 = Alertas, 1 = Historial
  late final WeatherService _weatherService;
  List<AlertaClimaModel> _alertasBackend = [];
  bool _cargando = true;

  final List<Map<String, dynamic>> _historial = [
    {
      'titulo': 'Viento fuerte en Paracas',
      'fecha': 'Ayer, 15:00',
      'descripcion': 'Se registraron ráfagas de 30 km/h.',
      'icono': Icons.history,
      'colorIcono': Colors.grey,
    },
    {
      'titulo': 'Cielo despejado en Ica',
      'fecha': 'Hace 3 días',
      'descripcion': 'Condiciones perfectas para turismo.',
      'icono': Icons.wb_sunny,
      'colorIcono': Colors.orange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _weatherService = widget.weatherService ?? WeatherService();
    _cargarAlertas();
  }

  Future<void> _cargarAlertas() async {
    setState(() => _cargando = true);
    final alertas = await _weatherService.getAlertasActivas();
    if (mounted) {
      setState(() {
        _alertasBackend = alertas;
        _cargando = false;
      });
    }
  }

  IconData _iconoAlerta(String code) {
    final c = code.toUpperCase();
    if (c.contains('VIENTO') || c.contains('PARACAS')) return Icons.air;
    if (c.contains('UV') || c.contains('SOL')) return Icons.wb_sunny;
    if (c.contains('LLUV') || c.contains('AGUA')) return Icons.water;
    return Icons.warning_amber_rounded;
  }

  Color _colorAlerta(String severity) {
    final s = severity.toUpperCase();
    if (s == 'HIGH' || s == 'CRITICAL') return Colors.red;
    if (s == 'MODERATE') return Colors.orange;
    return Colors.blue;
  }

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
                    'Alertas Climáticas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: AppColores.marronOscuro,
                      size: 26,
                    ),
                    onPressed: _cargarAlertas,
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
                    _botonToggle('Alertas activas', 0),
                    _botonToggle('Historial', 1),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Contenido
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargarAlertas,
                      child: _opcionSeleccionada == 0
                          ? _buildAlertasActivas()
                          : _buildHistorial(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertasActivas() {
    if (_alertasBackend.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 55, color: Colors.green),
            SizedBox(height: 10),
            Text(
              'No hay alertas climáticas adversas en la región.',
              style: TextStyle(color: AppColores.grisTexto, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _alertasBackend.length,
      itemBuilder: (context, index) {
        final alerta = _alertasBackend[index];
        final color = _colorAlerta(alerta.severity);
        final icono = _iconoAlerta(alerta.code);

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 28),
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
                          'Zona: ${alerta.zone}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColores.marronOscuro,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            alerta.severity,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
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

  Widget _buildHistorial() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
