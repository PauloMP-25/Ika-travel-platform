import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../services/weather_service.dart';

class PantallaDetalleDia extends StatefulWidget {
  final String tituloActividad;
  final String imagenActividad;
  final String? fecha;

  const PantallaDetalleDia({
    super.key,
    required this.tituloActividad,
    required this.imagenActividad,
    this.fecha,
  });

  @override
  State<PantallaDetalleDia> createState() => _PantallaDetalleDiaState();
}

class _PantallaDetalleDiaState extends State<PantallaDetalleDia> {
  final WeatherService _weatherService = WeatherService();

  Map<String, dynamic>? _climaActual;
  Map<String, dynamic>? _pronostico;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosClima();
  }

  String? _textoRecomendacionIA;
  List<dynamic> _consejosIA = [];

  Future<void> _cargarDatosClima() async {
    try {
      final clima = await _weatherService.obtenerClimaActual();
      final pron = await _weatherService.obtenerPronostico();
      final recIA = await _weatherService.obtenerRecomendacionDelDia();
      if (mounted) {
        setState(() {
          _climaActual = clima;
          _pronostico = pron;
          if (recIA != null) {
            _textoRecomendacionIA = recIA['recommendation_text'] as String?;
            _consejosIA = (recIA['consejos'] as List<dynamic>?) ?? [];
          }
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  String _obtenerFechaFormateada() {
    if (widget.fecha != null && widget.fecha!.isNotEmpty) {
      return widget.fecha!;
    }
    final ahora = DateTime.now();
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final diaSemana = dias[ahora.weekday - 1];
    final mes = meses[ahora.month - 1];
    final hora = DateFormat('hh:mm a').format(ahora);
    return '$diaSemana, ${ahora.day} de $mes de ${ahora.year} - $hora';
  }

  Widget _buildImagenCabecera() {
    if (widget.imagenActividad.startsWith('assets/')) {
      return Image.asset(
        widget.imagenActividad,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/carrusel_1_huacachina.jpg',
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.network(
      widget.imagenActividad,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/carrusel_1_huacachina.jpg',
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    final temp = _climaActual != null ? '${_climaActual!['temperatura_actual']?.round() ?? 21}°C' : '21°C';
    final viento = _climaActual != null ? '${_climaActual!['velocidad_viento']?.round() ?? 12} km/h' : '12 km/h';
    final humedad = _climaActual != null ? '${_climaActual!['humedad']?.round() ?? 76}%' : '76%';
    final lluvia = _climaActual != null ? '${_climaActual!['probabilidad_precipitacion']?.round() ?? 3}%' : '3%';
    final descripcion = _climaActual != null ? (_climaActual!['descripcion_clima'] ?? 'Cielo claro') : 'Cielo despejado';

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
                  child: _buildImagenCabecera(),
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
                    widget.tituloActividad.replaceAll('\n', ' '),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _obtenerFechaFormateada(),
                    style: TextStyle(fontSize: 13, color: colorTextoSecundario, fontWeight: FontWeight.w500),
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
                        child: Text('🌙', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Condición Nocturna en Ica',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorTexto,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cargando ? 'Consultando sensores...' : 'Estado actual: $descripcion. Temperatura templada ideal para paseos nocturnos.',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Datos en tiempo real (FastAPI)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorTexto,
                        ),
                      ),
                      if (_cargando)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
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
                          icono: Icons.water_drop_outlined,
                          valor: humedad,
                          etiqueta: 'Humedad',
                          colorTexto: colorTexto,
                          colorTextoSecundario: colorTextoSecundario,
                        ),
                        _MiniFactor(
                          icono: Icons.umbrella_outlined,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recomendación inteligente para esta hora',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.nightlight_round, color: AppColores.naranjaBoton, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Horario nocturno (19:30)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorTexto,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A esta hora en Ica la radiación UV es 0. Se recomienda llevar abrigo ligero ante la brisa nocturna ($viento) y planificar tours diurnos a partir de las 08:30 AM.',
                          style: TextStyle(fontSize: 13, color: colorTextoSecundario, height: 1.4),
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
          style: TextStyle(fontSize: 11, color: colorTextoSecundario),
        ),
      ],
    );
  }
}
