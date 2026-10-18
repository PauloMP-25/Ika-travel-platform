import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class PantallaPronostico extends StatefulWidget {
  final WeatherService? weatherService;

  const PantallaPronostico({super.key, this.weatherService});

  @override
  State<PantallaPronostico> createState() => _PantallaPronosticoState();
}

class _PantallaPronosticoState extends State<PantallaPronostico> {
  int _opcionSeleccionada = 0; // 0 = Hoy, 1 = Mañana, 2 = 7 días
  late final WeatherService _weatherService;

  ClimaActualModel? _climaActual;
  PronosticoCompletoModel? _pronostico;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _weatherService = widget.weatherService ?? WeatherService();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final climaFut = _weatherService.getClimaActual(destino: 'Ica');
    final pronosticoFut = _weatherService.getPronostico(destino: 'Ica');

    final resultados = await Future.wait([climaFut, pronosticoFut]);

    if (mounted) {
      setState(() {
        _climaActual = resultados[0] as ClimaActualModel;
        _pronostico = resultados[1] as PronosticoCompletoModel;
        _cargando = false;
      });
    }
  }

  IconData _mapearIcono(String condicion) {
    final c = condicion.toLowerCase();
    if (c.contains('lluv') || c.contains('precipita')) return Icons.water_drop;
    if (c.contains('viento') || c.contains('paracas')) return Icons.air;
    if (c.contains('nub')) return Icons.wb_cloudy;
    return Icons.wb_sunny;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      appBar: AppBar(
        title: const Text('Pronóstico del Clima', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector Hoy / Mañana / 7 Días
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _botonSelector(0, 'Hoy'),
                        const SizedBox(width: 10),
                        _botonSelector(1, 'Mañana'),
                        const SizedBox(width: 10),
                        _botonSelector(2, 'Próximos días'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tarjeta Principal de Resumen
                    _tarjetaResumenPrincipal(),

                    const SizedBox(height: 24),

                    // Vista condicional según selector
                    if (_opcionSeleccionada == 2) ...[
                      const Text(
                        'Pronóstico por días',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...(_pronostico?.dias.map(_tarjetaDia) ?? []),
                    ] else ...[
                      const Text(
                        'Pronóstico por horas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _pronostico?.horas.length ?? 0,
                          itemBuilder: (context, index) {
                            final hora = _pronostico!.horas[index];
                            return _tarjetaHora(hora);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _botonSelector(int indice, String texto) {
    final activo = _opcionSeleccionada == indice;
    return ChoiceChip(
      label: Text(
        texto,
        style: TextStyle(
          color: activo ? Colors.white : AppColores.marronOscuro,
          fontWeight: activo ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: activo,
      selectedColor: AppColores.naranjaBoton,
      backgroundColor: Colors.white,
      onSelected: (val) {
        if (val) setState(() => _opcionSeleccionada = indice);
      },
    );
  }

  Widget _tarjetaResumenPrincipal() {
    final clima = _climaActual;
    final temp = clima?.temperaturaActual.round() ?? 26;
    final condicion = clima?.descripcionClima ?? 'Despejado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColores.blancoTarjeta,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${clima?.destino ?? "Ica"}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Icon(_mapearIcono(condicion), size: 64, color: Colors.orange),
          const SizedBox(height: 10),
          Text(
            '$temp°C',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          Text(
            condicion,
            style: const TextStyle(fontSize: 16, color: AppColores.grisTexto),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _columnaDato('Viento', '${clima?.velocidadViento.round() ?? 12} km/h', Icons.air),
              _columnaDato('Humedad', '${clima?.humedad.round() ?? 48}%', Icons.water_drop),
              _columnaDato('UV', clima?.nivelUv ?? 'Alto', Icons.wb_sunny_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _columnaDato(String etiqueta, String valor, IconData icono) {
    return Column(
      children: [
        Icon(icono, size: 20, color: AppColores.naranjaBoton),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(etiqueta, style: const TextStyle(color: AppColores.grisTexto, fontSize: 11)),
      ],
    );
  }

  Widget _tarjetaHora(PronosticoHoraModel hora) {
    return Container(
      width: 85,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColores.blancoTarjeta,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(hora.horaFormato, style: const TextStyle(fontSize: 12, color: AppColores.grisTexto)),
          const SizedBox(height: 6),
          Icon(_mapearIcono(hora.condition), size: 28, color: Colors.orange),
          const SizedBox(height: 6),
          Text(
            '${hora.temperature.round()}°',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaDia(PronosticoDiaModel dia) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColores.blancoTarjeta,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              dia.date,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          Icon(_mapearIcono(dia.condition), color: Colors.orange),
          const SizedBox(width: 20),
          Text(
            '${dia.tempMin.round()}° / ${dia.tempMax.round()}°',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
