import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../config/traducciones_scope.dart';
import '../services/weather_service.dart';

class PantallaPronostico extends StatefulWidget {
  const PantallaPronostico({super.key});

  @override
  State<PantallaPronostico> createState() => _PantallaPronosticoState();
}

class _PantallaPronosticoState extends State<PantallaPronostico> {
  int _opcionSeleccionada = 0;
  bool _cargando = true;
  bool _refrescando = false;

  Map<String, dynamic>? _datosPronostico;
  Map<String, dynamic>? _datosClimaActual;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    if (!_refrescando) setState(() => _cargando = true);
    final weather = WeatherService();
    try {
      final pronostico = await weather.obtenerPronostico();
      final actual = await weather.obtenerClimaActual();
      if (!mounted) return;
      setState(() {
        _datosPronostico = pronostico;
        _datosClimaActual = actual;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _datosPronostico = null;
        _datosClimaActual = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
          _refrescando = false;
        });
      }
    }
  }

  Future<void> _refrescar() async {
    setState(() => _refrescando = true);
    await _cargarTodo();
  }

  bool get _sinDatos => _datosPronostico == null || _datosClimaActual == null;

  bool get _climaEsVigente {
    if (_sinDatos) return false;
    final fechaRaw =
        _datosClimaActual!['fecha_hora_pronostico'] ??
        _datosClimaActual!['updated_at'];
    if (fechaRaw == null) return false;
    final dt = DateTime.tryParse(fechaRaw.toString());
    if (dt == null) return false;
    return DateTime.now().difference(dt).inHours.abs() < 6;
  }

  Map<String, dynamic> _getDatosActuales() {
    if (_sinDatos) return {};

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
      tempActual =
          '${(_datosClimaActual!['temperatura_actual'] as num).round()}°C';
      condicion =
          _datosClimaActual!['descripcion_clima'] ??
          (diaHoy?['condition'] ?? 'Despejado');
      if (diaHoy != null) {
        tempMax = '${(diaHoy['temp_max'] as num).round()}°C';
        tempMin = '${(diaHoy['temp_min'] as num).round()}°C';
      }
      viento =
          '${(_datosClimaActual!['velocidad_viento'] as num).round()} km/h';
      humedad = '${(_datosClimaActual!['humedad'] as num).round()}%';
      uv = '${(_datosClimaActual!['indice_uv'] as num).round()}';
      lluvia =
          '${((_datosClimaActual!['probabilidad_precipitacion'] as num?) ?? diaHoy?['precipitation_probability_max'] ?? 0).round()}%';
    } else if (_opcionSeleccionada == 1) {
      if (diaManana != null) {
        tempActual = '${(diaManana['temp_max'] as num).round()}°C';
        condicion = diaManana['condition'] ?? 'Cielo despejado';
        tempMax = '${(diaManana['temp_max'] as num).round()}°C';
        tempMin = '${(diaManana['temp_min'] as num).round()}°C';
        viento = '${(diaManana['wind_speed_max'] as num?)?.round() ?? 14} km/h';
        humedad = '65%';
        uv = '${(diaManana['uv_index_max'] as num?)?.round() ?? 9}';
        lluvia =
            '${(diaManana['precipitation_probability_max'] as num?)?.round() ?? 5}%';
      }
    } else {
      if (dias.isNotEmpty) {
        final maxGlobal = dias
            .map<double>((d) => (d['temp_max'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);
        final minGlobal = dias
            .map<double>((d) => (d['temp_min'] as num).toDouble())
            .reduce((a, b) => a < b ? a : b);
        final vientoProm =
            dias
                .map<double>(
                  (d) => (d['wind_speed_max'] as num?)?.toDouble() ?? 12.0,
                )
                .reduce((a, b) => a + b) /
            dias.length;
        final uvMax = dias
            .map<double>((d) => (d['uv_index_max'] as num?)?.toDouble() ?? 8.0)
            .reduce((a, b) => a > b ? a : b);

        tempActual = '${maxGlobal.round()}°C';
        condicion = 'Pronóstico 7 días en Ica';
        tempMax = '${maxGlobal.round()}°C';
        tempMin = '${minGlobal.round()}°C';
        viento = '${vientoProm.round()} km/h';
        humedad = '${(_datosClimaActual!['humedad'] as num).round()}%';
        uv = '${uvMax.round()}';
        lluvia =
            '${(dias[0]['precipitation_probability_max'] as num?)?.round() ?? 0}%';
      }
    }

    List<dynamic> horasFiltradas;
    final ahora = DateTime.now();
    if (_opcionSeleccionada == 0) {
      final futuras = horas.where((h) {
        if (h['time'] == null) return true;
        final d = DateTime.parse(h['time']);
        return d.isAfter(ahora.subtract(const Duration(minutes: 50)));
      }).toList();
      horasFiltradas = futuras.isNotEmpty ? futuras.take(12).toList() : horas.take(12).toList();
    } else if (_opcionSeleccionada == 1) {
      final manana = ahora.add(const Duration(days: 1));
      final horasManana = horas.where((h) {
        if (h['time'] == null) return false;
        final d = DateTime.parse(h['time']);
        return d.day == manana.day;
      }).toList();
      horasFiltradas = horasManana.isNotEmpty ? horasManana.take(12).toList() : horas.skip(12).take(12).toList();
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

  String _fechaActual(BuildContext context) {
    final locale = context.locale.languageCode;
    return DateFormat('EEEE, d MMMM', locale).format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    if (_cargando) {
      return Scaffold(
        backgroundColor: TemaApp.fondo(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = _getDatosActuales();

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 8, 5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('pronostico_general'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorTexto,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ica · ${_fechaActual(context)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorTextoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('refrescar'),
                    icon: _refrescando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh, color: colorTexto),
                    onPressed: _refrescando ? null : _refrescar,
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
                    _botonToggle(context.tr('hoy'), 0, colorTextoSecundario),
                    _botonToggle(context.tr('manana'), 1, colorTextoSecundario),
                    _botonToggle(
                      context.tr('siete_dias'),
                      2,
                      colorTextoSecundario,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildChipEstado(context),
              ),
            ),
            const SizedBox(height: 12),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorTarjeta,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        color: colorTextoSecundario,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('error_pronostico'),
                        style: TextStyle(color: colorTexto),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _refrescar,
                        child: Text(context.tr('reintentar')),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
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
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final hora = DateTime.now().hour;
                                final esNoche = _opcionSeleccionada == 0 && (hora < 6 || hora >= 18);
                                final cond = (data['condicion'] ?? '').toString().toLowerCase();
                                IconData ic = esNoche ? Icons.nightlight_round : Icons.wb_sunny;
                                Color col = esNoche ? const Color(0xFFFFD54F) : Colors.orange;
                                if (cond.contains('lluv')) {
                                  ic = Icons.grain;
                                  col = Colors.lightBlue;
                                } else if (cond.contains('nub')) {
                                  ic = esNoche ? Icons.nights_stay : Icons.cloud;
                                  col = esNoche ? const Color(0xFF90CAF9) : Colors.blueGrey;
                                }
                                return Icon(ic, size: 45, color: col);
                              },
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      data['tempActual'],
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: colorTexto,
                                      ),
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      data['condicion'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorTextoSecundario,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${context.tr('max')} ${data['tempMax']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorTextoSecundario,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${context.tr('min')} ${data['tempMin']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorTextoSecundario,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                        etiqueta: context.tr('viento'),
                        colorTexto: colorTexto,
                        colorTextoSecundario: colorTextoSecundario,
                      ),
                      _MiniFactor(
                        icono: Icons.water_drop,
                        valor: data['humedad'],
                        etiqueta: context.tr('humedad'),
                        colorTexto: colorTexto,
                        colorTextoSecundario: colorTextoSecundario,
                      ),
                      _MiniFactor(
                        icono: Icons.water_drop_outlined,
                        valor: data['lluvia'] ?? '0%',
                        etiqueta: context.tr('lluvia'),
                        colorTexto: colorTexto,
                        colorTextoSecundario: colorTextoSecundario,
                      ),
                      _MiniFactor(
                        icono: Icons.wb_sunny,
                        valor: data['uv'],
                        etiqueta: context.tr('uv'),
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
                        _opcionSeleccionada == 2
                            ? context.tr('proximos_dias')
                            : context.tr('por_horas'),
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
                            IconData icHora = Icons.wb_sunny;
                            if (item['time'] != null) {
                              final date = DateTime.parse(item['time']);
                              final esNocheH = date.hour < 6 || date.hour >= 18;
                              final condH = (item['condition'] ?? '').toString().toLowerCase();
                              if (condH.contains('lluv')) {
                                icHora = Icons.grain;
                              } else if (condH.contains('nub')) {
                                icHora = esNocheH ? Icons.nights_stay : Icons.cloud;
                              } else {
                                icHora = esNocheH ? Icons.nightlight_round : Icons.wb_sunny;
                              }
                              if (_opcionSeleccionada == 2) {
                                horaFormateada = '${date.day}/${date.month}';
                              } else {
                                horaFormateada =
                                    '${date.hour.toString().padLeft(2, '0')}:00';
                              }
                            }
                            return _HoraItem(
                              hora: horaFormateada,
                              icono: icHora,
                              grados:
                                  '${(item['temperature'] as num).round()}°',
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
          ],
        ),
      ),
    );
  }

  Widget _buildChipEstado(BuildContext context) {
    if (_sinDatos) {
      return Tooltip(
        message: context.tr('sin_conexion_servidor'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 14, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                context.tr('sin_datos'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Tooltip(
      message: _climaEsVigente
          ? context.tr('datos_vigentes_tooltip')
          : context.tr('datos_referenciales_tooltip'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _climaEsVigente
              ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
              : Colors.amber.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _climaEsVigente
                ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                : Colors.amber.shade400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _climaEsVigente ? Icons.verified_outlined : Icons.history_rounded,
              size: 14,
              color: _climaEsVigente
                  ? const Color(0xFF1B5E20)
                  : Colors.brown.shade800,
            ),
            const SizedBox(width: 4),
            Text(
              _climaEsVigente
                  ? context.tr('datos_al_dia')
                  : context.tr('datos_referenciales'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _climaEsVigente
                    ? const Color(0xFF1B5E20)
                    : Colors.brown.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonToggle(String texto, int index, Color colorTextoSecundario) {
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
