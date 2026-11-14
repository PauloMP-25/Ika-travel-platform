import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/seguimiento_modelo.dart';
import '../services/alertas_service.dart';
import '../services/seguimiento_service.dart';
import '../services/weather_service.dart';
import 'pantalla_detalle_alerta.dart';

/// Pantalla de Seguimiento y Monitoreo de Destino (Requerimiento 14)
///
/// Las condiciones actuales se consultan al backend mediante WeatherService.
/// La aptitud operativa por actividad se calcula localmente a partir del
/// clima real. El historial cronologico de cambios se obtiene del backend
/// cuando hay datos suficientes; si no, se muestra un ejemplo simulado.
class PantallaSeguimientoDestino extends StatefulWidget {
  final String? nombreDestinoInicial;

  const PantallaSeguimientoDestino({super.key, this.nombreDestinoInicial});

  @override
  State<PantallaSeguimientoDestino> createState() =>
      _PantallaSeguimientoDestinoState();
}

class _PantallaSeguimientoDestinoState
    extends State<PantallaSeguimientoDestino> {
  final SeguimientoService _seguimientoService = SeguimientoService();
  final AlertasService _alertasService = AlertasService();
  final WeatherService _weatherService = WeatherService();

  late String _destinoSeleccionadoId;

  Map<String, dynamic>? _climaReal;
  bool _cargandoClima = false;
  String? _errorClima;
  bool _esFallbackOffline = false;

  // Historial real desde el backend
  List<Map<String, dynamic>> _historialReal = [];
  bool _cargandoHistorial = false;
  bool _historialCargado = false;

  @override
  void initState() {
    super.initState();
    final destinos = _seguimientoService.destinosNotifier.value;
    if (widget.nombreDestinoInicial != null && destinos.isNotEmpty) {
      final inicial = _seguimientoService.obtenerPorNombre(
        widget.nombreDestinoInicial!,
      );
      _destinoSeleccionadoId = inicial?.id ?? destinos.first.id;
    } else {
      _destinoSeleccionadoId = destinos.isNotEmpty
          ? destinos.first.id
          : 'huacachina';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cargarClimaReal(_destinoSeleccionadoId);
    });
  }

  String _destinoParaConsulta(DestinoSeguimiento? destino) {
    if (destino == null) return 'huacachina';
    final nombre = destino.nombre.toLowerCase();
    if (nombre.contains('huacachina')) return 'huacachina';
    if (nombre.contains('ballestas') || nombre.contains('isla')) {
      return 'islas ballestas';
    }
    if (nombre.contains('paracas')) return 'reserva nacional de paracas';
    if (nombre.contains('luren') || nombre.contains('centro')) {
      return 'plaza de armas de ica';
    }
    if (nombre.contains('campiña') ||
        nombre.contains('bodega') ||
        nombre.contains('vino') ||
        nombre.contains('viñedo')) {
      return 'bodega tacama';
    }
    if (nombre.contains('cachiche')) return 'pueblo de cachiche';
    if (nombre.contains('cañon') || nombre.contains('cañón')) {
      return 'cañon de los perdidos';
    }
    if (nombre.contains('pisco')) return 'plaza de armas de pisco';
    if (nombre.contains('chincha')) return 'plaza de armas de chincha';
    if (nombre.contains('marcona')) return 'playa hermosa de marcona';
    if (nombre.contains('chaco')) return 'playa el chaco';
    if (nombre.contains('playa roja')) return 'playa roja';
    if (nombre.contains('playa la mina') || nombre.contains('la mina')) {
      return 'playa la mina';
    }
    if (nombre.contains('cerro blanco')) return 'cerro blanco';
    return 'huacachina';
  }

  Future<void> _cargarClimaReal(String destinoId) async {
    final destino = _seguimientoService.obtenerPorId(destinoId);
    final nombreConsulta = _destinoParaConsulta(destino);

    _cargandoClima = true;
    _errorClima = null;
    if (mounted) setState(() {});

    try {
      final clima = await _weatherService.obtenerClimaActual(
        destino: nombreConsulta,
      );
      if (!mounted) return;
      final esFallbackOffline = clima?['origen_api'] == null;
      setState(() {
        _climaReal = clima;
        _esFallbackOffline = esFallbackOffline;
        _cargandoClima = false;
        _errorClima = esFallbackOffline
            ? 'Sin conexion al backend, mostrando datos de referencia'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoClima = false;
        _esFallbackOffline = true;
        _errorClima = 'No se pudo consultar el clima del destino';
      });
    }

    // Tambien cargar el historial real desde el backend
    _cargarHistorialReal(nombreConsulta);
  }

  Future<void> _cargarHistorialReal(String destinoConsulta) async {
    if (!mounted) return;
    setState(() {
      _cargandoHistorial = true;
      _historialCargado = false;
    });
    try {
      final historial = await _weatherService.obtenerHistorialDestino(
        destinoConsulta,
        horas: 24,
        limite: 10,
      );
      if (!mounted) return;
      setState(() {
        _historialReal = historial;
        _historialCargado = true;
        _cargandoHistorial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoHistorial = false;
        _historialCargado = false;
      });
    }
  }

  void _cambiarDestino(String id) {
    if (id == _destinoSeleccionadoId) return;
    setState(() {
      _destinoSeleccionadoId = id;
      _historialReal = [];
      _historialCargado = false;
    });
    _cargarClimaReal(id);
  }

  String _formatearFechaHora(DateTime dt) {
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    final hoy = DateTime.now();
    if (dt.day == hoy.day && dt.month == hoy.month && dt.year == hoy.year) {
      return 'Hoy, $hora:$minuto';
    } else if (hoy.difference(dt).inDays <= 1) {
      return 'Ayer, $hora:$minuto';
    } else {
      return 'Hace ${hoy.difference(dt).inDays} dias, $hora:$minuto';
    }
  }

  DateTime? _parseFecha(String? fecha) {
    if (fecha == null) return null;
    try {
      return DateTime.parse(fecha).toLocal();
    } catch (_) {
      return null;
    }
  }

  double _num(Map<String, dynamic>? m, String key, double fallback) {
    if (m == null) return fallback;
    final v = m[key];
    if (v is num) return v.toDouble();
    return fallback;
  }

  String _formatearTemperatura() {
    if (_climaReal == null) return '';
    final t = _num(_climaReal, 'temperatura_actual', 0);
    return '${t.round()}°C';
  }

  String _formatearViento() {
    if (_climaReal == null) return '';
    final v = _num(_climaReal, 'velocidad_viento', 0);
    return '${v.round()} km/h';
  }

  String _formatearHumedad() {
    if (_climaReal == null) return '';
    final h = _num(_climaReal, 'humedad', 0);
    return '${h.round()}%';
  }

  String _formatearUV() {
    if (_climaReal == null) return '';
    final uv = _num(_climaReal, 'indice_uv', 0);
    return uv.round().toString();
  }

  String _estadoGeneralReal() {
    if (_climaReal == null) return '';
    final temp = _num(_climaReal, 'temperatura_actual', 25);
    final viento = _num(_climaReal, 'velocidad_viento', 10);
    final uv = _num(_climaReal, 'indice_uv', 5);
    if (temp >= 36 || viento >= 40 || uv >= 11) {
      return 'Condiciones adversas. Actividades con restricciones.';
    }
    if (temp >= 31 || viento >= 25 || uv >= 8) {
      return 'Condiciones moderadas. Realiza actividades con precaucion.';
    }
    return 'Condiciones favorables para actividades al aire libre.';
  }

  List<AptitudActividad>? _calcularAptitudReal(DestinoSeguimiento destino) {
    if (_climaReal == null) return null;
    final temp = _num(_climaReal, 'temperatura_actual', 25);
    final viento = _num(_climaReal, 'velocidad_viento', 10);
    final uv = _num(_climaReal, 'indice_uv', 5);

    return destino.actividadesAptitud.map((base) {
      final titulo = base.actividadTitulo.toLowerCase();
      double vientoMax = 30;
      double tempMax = 34;
      double uvMax = 9;

      if (titulo.contains('sandboard') || titulo.contains('buggy')) {
        vientoMax = 28;
        tempMax = 35;
        uvMax = 10;
      } else if (titulo.contains('bote') ||
          titulo.contains('isla') ||
          titulo.contains('mar')) {
        vientoMax = 25;
        tempMax = 32;
        uvMax = 9;
      } else if (titulo.contains('vino') ||
          titulo.contains('cata') ||
          titulo.contains('bodega') ||
          titulo.contains('museo') ||
          titulo.contains('luren') ||
          titulo.contains('centro')) {
        vientoMax = 40;
        tempMax = 36;
        uvMax = 11;
      }

      final estado = _semaforo(
        viento: viento,
        temp: temp,
        uv: uv,
        vientoMax: vientoMax,
        tempMax: tempMax,
        uvMax: uvMax,
      );

      final detalle = _detalleAptitud(
        estado: estado,
        viento: viento,
        temp: temp,
        uv: uv,
        vientoMax: vientoMax,
        tempMax: tempMax,
        uvMax: uvMax,
      );

      return AptitudActividad(
        actividadTitulo: base.actividadTitulo,
        estado: estado,
        detalleClimatico: detalle,
      );
    }).toList();
  }

  EstadoAptitud _semaforo({
    required double viento,
    required double temp,
    required double uv,
    required double vientoMax,
    required double tempMax,
    required double uvMax,
  }) {
    if (viento > vientoMax * 1.3 || temp > tempMax + 4 || uv > uvMax + 2) {
      return EstadoAptitud.noRecomendada;
    }
    if (viento > vientoMax || temp > tempMax || uv > uvMax) {
      return EstadoAptitud.precaucion;
    }
    return EstadoAptitud.optima;
  }

  String _detalleAptitud({
    required EstadoAptitud estado,
    required double viento,
    required double temp,
    required double uv,
    required double vientoMax,
    required double tempMax,
    required double uvMax,
  }) {
    switch (estado) {
      case EstadoAptitud.optima:
        return 'Viento ${viento.round()} km/h, temperatura ${temp.round()}°C, UV ${uv.round()}. Ventana operativa segura.';
      case EstadoAptitud.precaucion:
        final razones = <String>[];
        if (viento > vientoMax) razones.add('viento elevado');
        if (temp > tempMax) razones.add('temperatura alta');
        if (uv > uvMax) razones.add('radiacion UV intensa');
        return 'Realizar con precaucion por ${razones.join(', ')}.';
      case EstadoAptitud.noRecomendada:
        return 'No recomendada: viento ${viento.round()} km/h, temperatura ${temp.round()}°C, UV ${uv.round()}.';
      case EstadoAptitud.suspendida:
        return 'Operacion suspendida por condiciones extremas.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DestinoSeguimiento>>(
      valueListenable: _seguimientoService.destinosNotifier,
      builder: (context, destinos, _) {
        final destinoActual = destinos.firstWhere(
          (d) => d.id == _destinoSeleccionadoId,
          orElse: () => destinos.first,
        );

        return Scaffold(
          backgroundColor: AppColores.arenaFondo,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColores.marronOscuro,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Seguimiento del Destino',
              style: TextStyle(
                color: AppColores.marronOscuro,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Actualizar condiciones',
                icon: _cargandoClima
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColores.naranjaBoton,
                        ),
                      )
                    : const Icon(Icons.refresh, color: AppColores.marronOscuro),
                onPressed: _cargandoClima
                    ? null
                    : () => _cargarClimaReal(_destinoSeleccionadoId),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _buildSelectorDestinos(destinos),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBannerEstado(),
                      const SizedBox(height: 14),
                      _buildTarjetaEstadoActual(destinoActual),
                      const SizedBox(height: 16),
                      _buildCondicionesActividades(destinoActual),
                      const SizedBox(height: 20),
                      _buildHistorialCambios(destinoActual),
                      const SizedBox(height: 20),
                      _buildAlertasRelacionadas(destinoActual),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerEstado() {
    final conectado = _climaReal != null && _errorClima == null;
    final colorFondo = conectado
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final colorBorde = conectado
        ? const Color(0xFFA5D6A7)
        : const Color(0xFFFFCC80);
    final colorTexto = conectado
        ? const Color(0xFF1B5E20)
        : const Color(0xFFBF360C);
    final icono = conectado ? Icons.cloud_done : Icons.cloud_off;
    final texto = _cargandoClima
        ? 'Actualizando condiciones climaticas...'
        : conectado
        ? 'Condiciones climaticas actualizadas.'
        : 'Sin conexion. Mostrando datos de referencia.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorde),
      ),
      child: Row(
        children: [
          Icon(icono, color: colorTexto, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                color: colorTexto,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorDestinos(List<DestinoSeguimiento> destinos) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: destinos.length,
        itemBuilder: (context, index) {
          final dest = destinos[index];
          final seleccionado = dest.id == _destinoSeleccionadoId;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(dest.nombre),
              selected: seleccionado,
              selectedColor: AppColores.marronOscuro,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: seleccionado ? Colors.white : AppColores.marronOscuro,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: seleccionado
                      ? AppColores.marronOscuro
                      : Colors.grey.shade300,
                ),
              ),
              onSelected: (val) {
                if (val) _cambiarDestino(dest.id);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTarjetaEstadoActual(DestinoSeguimiento destino) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _alertasService.destinosSeguidosNotifier,
      builder: (context, seguidos, _) {
        final loSigue = seguidos.contains(destino.nombre);

        final hayClimaReal = _climaReal != null;
        final temp = hayClimaReal
            ? _formatearTemperatura()
            : destino.temperaturaActual;
        final viento = hayClimaReal ? _formatearViento() : destino.vientoActual;
        final humedad = hayClimaReal
            ? _formatearHumedad()
            : destino.humedadActual;
        final uv = hayClimaReal ? _formatearUV() : destino.uvActual;
        final estado = hayClimaReal
            ? _estadoGeneralReal()
            : destino.estadoGeneral;
        final ultimaAct = hayClimaReal
            ? DateTime.now()
            : destino.ultimaActualizacion;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: Image.asset(
                        destino.imagen,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destino.nombre,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppColores.marronOscuro,
                          ),
                        ),
                        Text(
                          destino.region,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColores.grisTexto,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.update,
                              size: 14,
                              color: AppColores.naranjaBoton,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Actualizado: ${_formatearFechaHora(ultimaAct)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColores.naranjaBoton,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColores.arenaFondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColores.marronOscuro,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        estado,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _itemMetricaChip(
                      Icons.thermostat,
                      'Temperatura',
                      temp,
                    ),
                  ),
                  Expanded(
                    child: _itemMetricaChip(Icons.air, 'Viento', viento),
                  ),
                  Expanded(
                    child: _itemMetricaChip(
                      Icons.water_drop,
                      'Humedad',
                      humedad,
                    ),
                  ),
                  Expanded(child: _itemMetricaChip(Icons.wb_sunny, 'UV', uv)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: loSigue
                        ? const Color(0xFFC62828)
                        : AppColores.marronOscuro,
                    side: BorderSide(
                      color: loSigue
                          ? const Color(0xFFC62828)
                          : AppColores.marronOscuro,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    loSigue
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                    size: 18,
                  ),
                  label: Text(
                    loSigue
                        ? 'Dejar de seguir alertas de este destino'
                        : 'Seguir y recibir alertas de este destino',
                  ),
                  onPressed: () {
                    _alertasService.toggleSeguirDestino(destino.nombre);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loSigue
                              ? 'Dejaste de seguir las alertas de ${destino.nombre}'
                              : 'Ahora sigues ${destino.nombre}. Recibiras alertas sobre sus condiciones.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _itemMetricaChip(IconData icono, String titulo, String valor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 20, color: AppColores.naranjaBoton),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 11, color: AppColores.grisTexto),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColores.marronOscuro,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCondicionesActividades(DestinoSeguimiento destino) {
    final aptitudes =
        _calcularAptitudReal(destino) ?? destino.actividadesAptitud;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Condiciones para actividades disponibles',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColores.marronOscuro,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _climaReal != null
              ? 'Semaforo calculado en tiempo real a partir del clima consultado al backend'
              : 'Semaforo de referencia. Consulta el clima real para actualizar',
          style: const TextStyle(fontSize: 12, color: AppColores.grisTexto),
        ),
        const SizedBox(height: 10),
        ...aptitudes.map((apt) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: apt.estado.color.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(apt.estado.icono, color: apt.estado.color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              apt.actividadTitulo,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColores.marronOscuro,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: apt.estado.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              apt.estado.etiqueta,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: apt.estado.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        apt.detalleClimatico,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHistorialCambios(DestinoSeguimiento destino) {
    // Considerar "real" si el backend respondio, aunque la lista este vacia.
    // Solo caer al mock si el backend fallo (timeout, error de red, etc).
    final usandoReal = _historialCargado;
    final registros = usandoReal
        ? _historialReal
        : destino.historialCambios
              .map(
                (r) => {
                  'fecha': r.fechaHora.toIso8601String(),
                  'parametro': r.parametroModificado,
                  'valor_anterior': r.valorAnterior,
                  'valor_actual': r.valorActual,
                  'resumen': r.resumenImpacto,
                  'alerta_id': r.alertaIdAsociada,
                },
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Historial cronologico de cambios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColores.marronOscuro,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: usandoReal
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                usandoReal ? 'Actualizado' : 'Referencia',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: usandoReal
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFFBF360C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          usandoReal
              ? 'Ultimos cambios registrados en las condiciones del destino.'
              : 'Cambios de ejemplo. Aun no hay suficiente historial registrado.',
          style: const TextStyle(fontSize: 12, color: AppColores.grisTexto),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _cargandoHistorial
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : registros.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Sin cambios significativos en las ultimas 24 h. Las condiciones del destino se mantienen estables.',
                    style: TextStyle(fontSize: 13, color: AppColores.grisTexto),
                  ),
                )
              : Column(
                  children: registros.map((reg) {
                    final fecha = _parseFecha(reg['fecha']?.toString());
                    final alertaId = reg['alerta_id']?.toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.only(bottom: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFEEEEEE),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  (reg['parametro'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColores.marronOscuro,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                fecha != null ? _formatearFechaHora(fecha) : '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColores.grisTexto,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Anterior: ${reg['valor_anterior'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColores.grisTexto,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppColores.naranjaBoton,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Actual: ${reg['valor_actual'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColores.naranjaBoton,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (reg['resumen'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          if (alertaId != null &&
                              alertaId.isNotEmpty &&
                              alertaId != 'null') ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                final alerta = _alertasService
                                    .obtenerAlertaPorId(alertaId);
                                if (alerta != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          PantallaDetalleAlerta(alerta: alerta),
                                    ),
                                  );
                                }
                              },
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.open_in_new,
                                    size: 13,
                                    color: AppColores.naranjaBoton,
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Ver detalle de la alerta asociada',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColores.naranjaBoton,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildAlertasRelacionadas(DestinoSeguimiento destino) {
    final todas = _alertasService.alertasNotifier.value;
    final alertasDestino = todas
        .where(
          (a) => a.destino.toLowerCase().contains(
            destino.nombre.toLowerCase().split(' ').first,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Alertas relacionadas con el destino',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColores.marronOscuro,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${alertasDestino.length} registros',
              style: const TextStyle(fontSize: 12, color: AppColores.grisTexto),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (alertasDestino.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No hay alertas registradas para este destino.',
                style: TextStyle(fontSize: 13, color: AppColores.grisTexto),
              ),
            ),
          )
        else
          ...alertasDestino.map((alerta) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: alerta.nivelRiesgo.colorFondo,
                    child: Icon(
                      alerta.nivelRiesgo.icono,
                      color: alerta.nivelRiesgo.color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    alerta.titulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  subtitle: Text(
                    '${alerta.actividad.replaceAll('\n', ' ')} - ${_formatearFechaHora(alerta.fechaHora)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColores.grisTexto,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColores.grisTexto,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PantallaDetalleAlerta(alerta: alerta),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}
