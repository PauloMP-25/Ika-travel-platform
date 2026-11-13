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
      horasFiltradas = futuras.isNotEmpty
          ? futuras.take(12).toList()
          : horas.take(12).toList();
    } else if (_opcionSeleccionada == 1) {
      final manana = ahora.add(const Duration(days: 1));
      final horasManana = horas.where((h) {
        if (h['time'] == null) return false;
        final d = DateTime.parse(h['time']);
        return d.day == manana.day;
      }).toList();
      horasFiltradas = horasManana.isNotEmpty
          ? horasManana.take(12).toList()
          : horas.skip(12).take(12).toList();
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

  /// Ícono del clima según la condición y si es de noche.
  IconData _iconoClima(String condicion, bool esNoche) {
    final c = condicion.toLowerCase();
    if (c.contains('torment')) return Icons.thunderstorm;
    if (c.contains('lluv') || c.contains('llovizna')) return Icons.grain;
    if (c.contains('nub') || c.contains('cubierto')) {
      return esNoche ? Icons.nights_stay : Icons.cloud;
    }
    return esNoche ? Icons.nightlight_round : Icons.wb_sunny;
  }

  /// Degradado de la tarjeta principal según condición y hora.
  List<Color> _gradienteClima(String condicion, bool esNoche) {
    final c = condicion.toLowerCase();
    if (c.contains('torment')) {
      return const [Color(0xFF3A4A66), Color(0xFF1C2433)];
    }
    if (c.contains('lluv') || c.contains('llovizna')) {
      return const [Color(0xFF4B6CB7), Color(0xFF26418A)];
    }
    if (c.contains('nub') || c.contains('cubierto')) {
      return esNoche
          ? const [Color(0xFF3B4466), Color(0xFF232A43)]
          : const [Color(0xFF7C8CA0), Color(0xFF566073)];
    }
    if (esNoche) {
      return const [Color(0xFF2B3A82), Color(0xFF151A40)];
    }
    // Soleado: degradado cálido de dunas.
    return const [Color(0xFFFFB24C), Color(0xFFF2691C)];
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    if (_cargando) {
      return Scaffold(
        backgroundColor: TemaApp.fondo(context),
        body: const Center(
          child: CircularProgressIndicator(color: AppColores.naranjaBoton),
        ),
      );
    }

    final data = _getDatosActuales();

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('pronostico_general'),
                          style: TextStyle(
                            fontSize: 22,
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
            // Selector Hoy / Mañana / 7 días
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorTextoSecundario.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
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
            const SizedBox(height: 14),
            Expanded(
              child: data.isEmpty
                  ? _vistaSinDatos(context, colorTarjeta, colorTexto,
                      colorTextoSecundario)
                  : RefreshIndicator(
                      color: AppColores.naranjaBoton,
                      onRefresh: _refrescar,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: [
                          _tarjetaPrincipal(context, data, colorTextoSecundario),
                          const SizedBox(height: 14),
                          _filaMetricas(context, data, colorTexto, colorTarjeta,
                              colorTextoSecundario),
                          const SizedBox(height: 22),
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
                          const SizedBox(height: 12),
                          _listaHoras(context, data, colorTexto, colorTarjeta,
                              colorTextoSecundario),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vistaSinDatos(BuildContext context, Color colorTarjeta,
      Color colorTexto, Color colorTextoSecundario) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorTarjeta,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_off, color: colorTextoSecundario, size: 44),
              const SizedBox(height: 10),
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
      ],
    );
  }

  Widget _tarjetaPrincipal(
    BuildContext context,
    Map<String, dynamic> data,
    Color colorTextoSecundario,
  ) {
    final condicion = (data['condicion'] ?? '').toString();
    final hora = DateTime.now().hour;
    final esNoche =
        _opcionSeleccionada == 0 && (hora < 6 || hora >= 18);
    final grad = _gradienteClima(condicion, esNoche);
    final icono = _iconoClima(condicion, esNoche);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: grad,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: grad.last.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  condicion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _chipEstadoClaro(context),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(icono, size: 62, color: Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data['tempActual'],
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _pillMaxMin(Icons.arrow_upward, data['tempMax']),
                  const SizedBox(height: 6),
                  _pillMaxMin(Icons.arrow_downward, data['tempMin']),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillMaxMin(IconData icono, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaMetricas(
    BuildContext context,
    Map<String, dynamic> data,
    Color colorTexto,
    Color colorTarjeta,
    Color colorTextoSecundario,
  ) {
    final items = [
      (Icons.air, data['viento'], context.tr('viento'), AppColores.turquesaOasis),
      (Icons.water_drop, data['humedad'], context.tr('humedad'),
          AppColores.azulParacas),
      (Icons.umbrella, data['lluvia'] ?? '0%', context.tr('lluvia'),
          const Color(0xFF3D9BE9)),
      (Icons.wb_sunny, data['uv'], context.tr('uv'), AppColores.naranjaBoton),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _MetricaChip(
              icono: items[i].$1,
              valor: items[i].$2,
              etiqueta: items[i].$3,
              colorAcento: items[i].$4,
              colorTexto: colorTexto,
              colorTextoSecundario: colorTextoSecundario,
              colorTarjeta: colorTarjeta,
            ),
          ),
        ],
      ],
    );
  }

  Widget _listaHoras(
    BuildContext context,
    Map<String, dynamic> data,
    Color colorTexto,
    Color colorTarjeta,
    Color colorTextoSecundario,
  ) {
    final lista = data['porHoras'] as List;
    return SizedBox(
      height: 118,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final item = lista[index];
          String horaFormateada = '--';
          IconData icHora = Icons.wb_sunny;
          if (item['time'] != null) {
            final date = DateTime.parse(item['time']);
            final esNocheH = date.hour < 6 || date.hour >= 18;
            icHora = _iconoClima(
              (item['condition'] ?? '').toString(),
              _opcionSeleccionada == 2 ? false : esNocheH,
            );
            if (_opcionSeleccionada == 2) {
              horaFormateada = '${date.day}/${date.month}';
            } else {
              horaFormateada = '${date.hour.toString().padLeft(2, '0')}:00';
            }
          }
          return _HoraItem(
            hora: horaFormateada,
            icono: icHora,
            grados: '${(item['temperature'] as num).round()}°',
            destacado: index == 0,
            colorTexto: colorTexto,
            colorTextoSecundario: colorTextoSecundario,
            colorTarjeta: colorTarjeta,
          );
        },
      ),
    );
  }

  /// Chip de estado (versión clara, para ir sobre el degradado).
  Widget _chipEstadoClaro(BuildContext context) {
    final vigente = _climaEsVigente;
    return Tooltip(
      message: vigente
          ? context.tr('datos_vigentes_tooltip')
          : context.tr('datos_referenciales_tooltip'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              vigente ? Icons.verified_outlined : Icons.history_rounded,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              vigente
                  ? context.tr('datos_al_dia')
                  : context.tr('datos_referenciales'),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: activo ? AppColores.naranjaBoton : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: AppColores.naranjaBoton.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                color: activo ? Colors.white : colorTextoSecundario,
                fontWeight: activo ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricaChip extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color colorAcento;
  final Color colorTexto;
  final Color colorTextoSecundario;
  final Color colorTarjeta;

  const _MetricaChip({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    required this.colorAcento,
    required this.colorTexto,
    required this.colorTextoSecundario,
    required this.colorTarjeta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: colorTarjeta,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorAcento.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: colorAcento, size: 19),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorTexto,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: TextStyle(fontSize: 10, color: colorTextoSecundario),
          ),
        ],
      ),
    );
  }
}

class _HoraItem extends StatelessWidget {
  final String hora;
  final IconData icono;
  final String grados;
  final bool destacado;
  final Color colorTexto;
  final Color colorTextoSecundario;
  final Color colorTarjeta;

  const _HoraItem({
    required this.hora,
    required this.icono,
    required this.grados,
    required this.destacado,
    required this.colorTexto,
    required this.colorTextoSecundario,
    required this.colorTarjeta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: destacado ? AppColores.naranjaClaro : colorTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: destacado
            ? Border.all(color: AppColores.naranjaBoton.withValues(alpha: 0.5))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hora,
            style: TextStyle(
              fontSize: 12,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
              color: destacado ? AppColores.naranjaBoton : colorTextoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            icono,
            color: destacado ? AppColores.naranjaBoton : colorTexto,
            size: 22,
          ),
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
