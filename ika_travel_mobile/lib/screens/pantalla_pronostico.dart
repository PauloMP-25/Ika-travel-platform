import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../services/weather_service.dart';

class PantallaPronostico extends StatefulWidget {
  const PantallaPronostico({super.key});

  @override
  State<PantallaPronostico> createState() => _PantallaPronosticoState();
}

class _PantallaPronosticoState extends State<PantallaPronostico> {
  int _opcionSeleccionada = 0;
  bool _cargando = true;

  Map<String, dynamic>? _datosPronostico;
  Map<String, dynamic>? _datosClimaActual;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    final weather = WeatherService();
    final pronostico = await weather.obtenerPronostico();
    final actual = await weather.obtenerClimaActual();
    setState(() {
      _datosPronostico = pronostico;
      _datosClimaActual = actual;
      _cargando = false;
    });
  }

  Map<String, dynamic> _getDatosActuales() {
    if (_datosPronostico == null || _datosClimaActual == null) {
      return {};
    }

    final horas = (_datosPronostico!['horas'] as List?) ?? [];
    final dias = (_datosPronostico!['dias'] as List?) ?? [];

    String tempActual = '--';
    String condicion = '--';
    String tempMax = '--';
    String tempMin = '--';
    String viento = '--';
    String humedad = '--';
    String uv = '--';
    String lluvia = '0%';

    final diaHoy = dias.isNotEmpty ? dias[0] : null;
    final diaManana = dias.length > 1 ? dias[1] : diaHoy;

    if (_opcionSeleccionada == 0) {
      // Pestaña: HOY
      tempActual = '${(_datosClimaActual!['temperatura_actual'] as num).round()}°C';
      condicion = _datosClimaActual!['descripcion_clima'] ?? (diaHoy?['condition'] ?? 'Despejado');
      if (diaHoy != null) {
        tempMax = '${(diaHoy['temp_max'] as num).round()}°C';
        tempMin = '${(diaHoy['temp_min'] as num).round()}°C';
      }
      viento = '${(_datosClimaActual!['velocidad_viento'] as num).round()} km/h';
      humedad = '${(_datosClimaActual!['humedad'] as num).round()}%';
      uv = '${(_datosClimaActual!['indice_uv'] as num).round()}';
      lluvia = '${((_datosClimaActual!['probabilidad_precipitacion'] as num?) ?? diaHoy?['precipitation_probability_max'] ?? 0).round()}%';
    } else if (_opcionSeleccionada == 1) {
      // Pestaña: MAÑANA (refleja el pronóstico del día siguiente)
      if (diaManana != null) {
        tempActual = '${(diaManana['temp_max'] as num).round()}°C';
        condicion = diaManana['condition'] ?? 'Cielo despejado';
        tempMax = '${(diaManana['temp_max'] as num).round()}°C';
        tempMin = '${(diaManana['temp_min'] as num).round()}°C';
        viento = '${(diaManana['wind_speed_max'] as num?)?.round() ?? 14} km/h';
        humedad = '65%';
        uv = '${(diaManana['uv_index_max'] as num?)?.round() ?? 9}';
        lluvia = '${(diaManana['precipitation_probability_max'] as num?)?.round() ?? 5}%';
      }
    } else {
      // Pestaña: 7 DÍAS (promedio y rango semanal)
      if (dias.isNotEmpty) {
        final double maxGlobal = dias.map<double>((d) => (d['temp_max'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
        final double minGlobal = dias.map<double>((d) => (d['temp_min'] as num).toDouble()).reduce((a, b) => a < b ? a : b);
        final double vientoProm = dias.map<double>((d) => (d['wind_speed_max'] as num?)?.toDouble() ?? 12.0).reduce((a, b) => a + b) / dias.length;
        final double uvMax = dias.map<double>((d) => (d['uv_index_max'] as num?)?.toDouble() ?? 8.0).reduce((a, b) => a > b ? a : b);

        tempActual = '${maxGlobal.round()}°C';
        condicion = 'Pronóstico 7 días en Ica';
        tempMax = '${maxGlobal.round()}°C';
        tempMin = '${minGlobal.round()}°C';
        viento = '${vientoProm.round()} km/h';
        humedad = '${(_datosClimaActual!['humedad'] as num).round()}%';
        uv = '${uvMax.round()}';
        lluvia = '${(dias[0]['precipitation_probability_max'] as num?)?.round() ?? 0}%';
      }
    }

    List<dynamic> horasFiltradas = [];
    if (_opcionSeleccionada == 0) {
      horasFiltradas = horas.take(12).toList();
    } else if (_opcionSeleccionada == 1) {
      horasFiltradas = horas.skip(12).take(12).toList();
      if (horasFiltradas.isEmpty) horasFiltradas = horas.take(12).toList();
    } else {
      horasFiltradas = dias.map((dia) {
        return {
          'time': dia['date'],
          'temperature': dia['temp_max'],
          'condition': dia['condition'],
          'uv_index': dia['uv_index_max'],
          'wind_speed': dia['wind_speed_max'],
          'precipitation_probability': dia['precipitation_probability_max'],
        };
      }).toList();
    }

    return {
      'tempActual': tempActual,
      'condicion': condicion,
      'tempMax': tempMax,
      'tempMin': tempMin,
      'viento': viento,
      'humedad': humedad,
      'uv': uv,
      'lluvia': lluvia,
      'porHoras': horasFiltradas,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final data = _getDatosActuales();
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    if (data.isEmpty) {
      return Scaffold(
        backgroundColor: TemaApp.fondo(context),
        body: Center(
          child: Text(
            'Error al cargar el pronóstico',
            style: TextStyle(color: colorTexto),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                children: [
                  Text(
                    'Pronóstico general',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                  Text(
                    'Ica',
                    style: TextStyle(fontSize: 14, color: colorTextoSecundario),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: colorTarjeta,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _botonToggle('Hoy', 0, colorTexto, colorTextoSecundario),
                    _botonToggle('Mañana', 1, colorTexto, colorTextoSecundario),
                    _botonToggle('7 días', 2, colorTexto, colorTextoSecundario),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.wb_sunny,
                          size: 50,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['tempActual'],
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                            Text(
                              data['condicion'],
                              style: TextStyle(
                                fontSize: 14,
                                color: colorTextoSecundario,
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
                          'Máx. ${data['tempMax']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorTextoSecundario,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mín. ${data['tempMin']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorTextoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
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
                      icono: Icons.air,
                      valor: data['viento'],
                      etiqueta: 'Viento',
                      colorTexto: colorTexto,
                      colorTextoSecundario: colorTextoSecundario,
                    ),
                    _MiniFactor(
                      icono: Icons.water_drop,
                      valor: data['humedad'],
                      etiqueta: 'Humedad',
                      colorTexto: colorTexto,
                      colorTextoSecundario: colorTextoSecundario,
                    ),
                    _MiniFactor(
                      icono: Icons.water_drop_outlined,
                      valor: data['lluvia'] ?? '0%',
                      etiqueta: 'Lluvia',
                      colorTexto: colorTexto,
                      colorTextoSecundario: colorTextoSecundario,
                    ),
                    _MiniFactor(
                      icono: Icons.wb_sunny,
                      valor: data['uv'],
                      etiqueta: 'UV',
                      colorTexto: colorTexto,
                      colorTextoSecundario: colorTextoSecundario,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _opcionSeleccionada == 2 ? 'Próximos días' : 'Por horas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (data['porHoras'] as List).length,
                        itemBuilder: (context, index) {
                          final item = data['porHoras'][index];
                          String horaFormateada = '--';
                          if (item['time'] != null) {
                            final date = DateTime.parse(item['time']);
                            if (_opcionSeleccionada == 2) {
                              horaFormateada = '${date.day}/${date.month}';
                            } else {
                              horaFormateada =
                                  '${date.hour.toString().padLeft(2, '0')}:00';
                            }
                          }
                          return _HoraItem(
                            hora: horaFormateada,
                            icono: Icons.wb_sunny,
                            // 👇 REDONDEAMOS LA TEMPERATURA POR HORAS
                            grados: '${(item['temperature'] as num).round()}°',
                            colorTexto: colorTexto,
                            colorTextoSecundario: colorTextoSecundario,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonToggle(
    String texto,
    int index,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    final bool activo = _opcionSeleccionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _opcionSeleccionada = index),
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
                color: activo ? Colors.white : colorTextoSecundario,
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
        Icon(icono, color: colorTextoSecundario, size: 22),
        const SizedBox(height: 5),
        Text(
          etiqueta,
          style: TextStyle(fontSize: 10, color: colorTextoSecundario),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorTexto,
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
  final Color colorTexto;
  final Color colorTextoSecundario;

  const _HoraItem({
    required this.hora,
    required this.icono,
    required this.grados,
    required this.colorTexto,
    required this.colorTextoSecundario,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 25),
      child: Column(
        children: [
          Text(
            hora,
            style: TextStyle(fontSize: 12, color: colorTextoSecundario),
          ),
          const SizedBox(height: 8),
          Icon(icono, color: colorTexto, size: 20),
          const SizedBox(height: 8),
          Text(
            grados,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
        ],
      ),
    );
  }
}
