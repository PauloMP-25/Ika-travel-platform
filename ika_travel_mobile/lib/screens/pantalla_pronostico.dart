import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class PantallaPronostico extends StatefulWidget {
  const PantallaPronostico({super.key});

  @override
  State<PantallaPronostico> createState() => _PantallaPronosticoState();
}

class _PantallaPronosticoState extends State<PantallaPronostico> {
  int _opcionSeleccionada = 0; // 0 = Hoy, 1 = Mañana, 2 = 7 días
  final WeatherService _weatherService = WeatherService();
  late Future<PronosticoCompletoModel> _pronosticoFuture;

  @override
  void initState() {
    super.initState();
    _pronosticoFuture = _weatherService.getPronostico(destino: 'Ica');
  }

  void _refrescar() {
    setState(() {
      _pronosticoFuture = _weatherService.getPronostico(destino: 'Ica');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: FutureBuilder<PronosticoCompletoModel>(
          future: _pronosticoFuture,
          builder: (context, snapshot) {
            final pronostico = snapshot.data;
            final cargando = snapshot.connectionState == ConnectionState.waiting &&
                pronostico == null;

            final datos = _calcularDatos(pronostico);

            return SingleChildScrollView(
              child: Column(
                children: [
                  // 1. AppBar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pronóstico Meteorológico',
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
                            size: 26,
                          ),
                          onPressed: _refrescar,
                        ),
                      ],
                    ),
                  ),

                  // 2. Selector Hoy / Mañana / 7 días
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
                          _botonToggle('Hoy', 0),
                          _botonToggle('Mañana', 1),
                          _botonToggle('Próximos días', 2),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Tarjeta principal del pronóstico
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                datos['iconoPrincipal'] as IconData,
                                size: 50,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    datos['tempActual'] as String,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColores.marronOscuro,
                                    ),
                                  ),
                                  Text(
                                    datos['condicion'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColores.grisTexto,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Máx. ${datos['tempMax']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColores.grisTexto,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mín. ${datos['tempMin']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColores.grisTexto,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // 4. Fila de factores climáticos
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
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
                            icono: Icons.air,
                            valor: datos['viento'] as String,
                            etiqueta: 'Viento',
                          ),
                          _MiniFactor(
                            icono: Icons.water_drop,
                            valor: datos['humedad'] as String,
                            etiqueta: 'Humedad',
                          ),
                          _MiniFactor(
                            icono: Icons.water_drop_outlined,
                            valor: datos['lluvia'] as String,
                            etiqueta: 'Lluvia',
                          ),
                          _MiniFactor(
                            icono: Icons.wb_sunny,
                            valor: datos['uv'] as String,
                            etiqueta: 'UV',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 5. Por horas o próximos días
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _opcionSeleccionada == 2
                                ? 'Próximos días'
                                : 'Por horas en Ica',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  (datos['elementosHorizontales'] as List).length,
                              itemBuilder: (context, index) {
                                final item =
                                    (datos['elementosHorizontales'] as List)[index]
                                        as Map<String, dynamic>;
                                return _HoraItem(
                                  hora: item['hora'] as String,
                                  icono: item['icono'] as IconData,
                                  grados: item['grados'] as String,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (cargando)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        color: AppColores.naranjaBoton,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, dynamic> _calcularDatos(PronosticoCompletoModel? pronostico) {
    if (pronostico != null && pronostico.dias.isNotEmpty) {
      if (_opcionSeleccionada == 0) {
        final dia0 = pronostico.dias.first;
        return {
          'tempActual': '${dia0.tempMax.toStringAsFixed(0)}°C',
          'condicion': dia0.condition,
          'tempMax': '${dia0.tempMax.toStringAsFixed(0)}°C',
          'tempMin': '${dia0.tempMin.toStringAsFixed(0)}°C',
          'iconoPrincipal': Icons.wb_sunny,
          'viento': '${dia0.windSpeedMax.toStringAsFixed(0)} km/h',
          'humedad': '48%',
          'lluvia': '${dia0.precipitationProbabilityMax.toStringAsFixed(0)}%',
          'uv': dia0.uvIndexMax > 7 ? 'Muy Alto' : 'Moderado',
          'elementosHorizontales': pronostico.horas.map((h) {
            return {
              'hora': h.horaFormato,
              'icono': Icons.wb_sunny_rounded,
              'grados': '${h.temperature.toStringAsFixed(0)}°',
            };
          }).toList(),
        };
      } else if (_opcionSeleccionada == 1 && pronostico.dias.length > 1) {
        final dia1 = pronostico.dias[1];
        return {
          'tempActual': '${dia1.tempMax.toStringAsFixed(0)}°C',
          'condicion': dia1.condition,
          'tempMax': '${dia1.tempMax.toStringAsFixed(0)}°C',
          'tempMin': '${dia1.tempMin.toStringAsFixed(0)}°C',
          'iconoPrincipal': Icons.wb_cloudy_rounded,
          'viento': '${dia1.windSpeedMax.toStringAsFixed(0)} km/h',
          'humedad': '55%',
          'lluvia': '${dia1.precipitationProbabilityMax.toStringAsFixed(0)}%',
          'uv': dia1.uvIndexMax > 7 ? 'Alto' : 'Moderado',
          'elementosHorizontales': pronostico.horas.map((h) {
            return {
              'hora': h.horaFormato,
              'icono': Icons.cloud_outlined,
              'grados': '${(h.temperature - 1).toStringAsFixed(0)}°',
            };
          }).toList(),
        };
      } else {
        return {
          'tempActual': '24°C',
          'condicion': 'Despejado / Soleado',
          'tempMax': '27°C',
          'tempMin': '15°C',
          'iconoPrincipal': Icons.calendar_month_rounded,
          'viento': '15 km/h',
          'humedad': '50%',
          'lluvia': '5%',
          'uv': 'Alto',
          'elementosHorizontales': pronostico.dias.map((d) {
            return {
              'hora': d.date,
              'icono': Icons.wb_sunny,
              'grados': '${d.tempMax.toStringAsFixed(0)}°',
            };
          }).toList(),
        };
      }
    }

    // Fallback por defecto si aún no carga el backend
    return {
      'tempActual': '26°C',
      'condicion': 'Soleado',
      'tempMax': '27°C',
      'tempMin': '16°C',
      'iconoPrincipal': Icons.wb_sunny,
      'viento': '12 km/h',
      'humedad': '48%',
      'lluvia': '8%',
      'uv': 'Alto',
      'elementosHorizontales': [
        {'hora': '08:00', 'icono': Icons.wb_sunny, 'grados': '20°'},
        {'hora': '11:00', 'icono': Icons.wb_sunny, 'grados': '25°'},
        {'hora': '14:00', 'icono': Icons.wb_cloudy, 'grados': '25°'},
        {'hora': '17:00', 'icono': Icons.air, 'grados': '22°'},
        {'hora': '20:00', 'icono': Icons.nightlight_round, 'grados': '19°'},
      ],
    };
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
        Icon(icono, color: AppColores.grisTexto, size: 22),
        const SizedBox(height: 5),
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 10, color: AppColores.grisTexto),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColores.marronOscuro,
          ),
        ),
      ],
    );
  }
}

class _HoraItem extends StatelessWidget {
  final String hora;
  final IconData icono;
  final String grados;

  const _HoraItem({
    required this.hora,
    required this.icono,
    required this.grados,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 25),
      child: Column(
        children: [
          Text(
            hora,
            style: const TextStyle(fontSize: 12, color: AppColores.grisTexto),
          ),
          const SizedBox(height: 8),
          Icon(icono, color: AppColores.marronOscuro, size: 20),
          const SizedBox(height: 8),
          Text(
            grados,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColores.marronOscuro,
            ),
          ),
        ],
      ),
    );
  }
}
