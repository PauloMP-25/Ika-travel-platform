import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../config/favoritos_manager.dart';
import '../services/api_service.dart';
import '../services/alertas_service.dart';
import '../services/weather_service.dart';
import '../models/alerta_modelo.dart';
import '../models/horario_modelo.dart';
import '../widgets/tarjeta_horarios_atencion.dart';
import 'pantalla_detalle_dia.dart';
import 'pantalla_detalle_alerta.dart';
import 'pantalla_seguimiento_destino.dart';

class PantallaDetalle extends StatefulWidget {
  final String id;
  final String titulo;
  final String subtitulo;
  final List<String> imagenes;

  const PantallaDetalle({
    super.key,
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.imagenes,
  });

  @override
  State<PantallaDetalle> createState() => _PantallaDetalleState();
}

class _PantallaDetalleState extends State<PantallaDetalle> {
  int _paginaActual = 0;
  final AlertasService _alertasService = AlertasService();

  Map<String, dynamic>? _detalleBackend;
  Map<String, dynamic>? _clima;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final api = ApiService();
    final weather = WeatherService();

    final dataAtraccion = await api.obtenerDetalleAtraccion(widget.id);
    final dataClima = await weather.obtenerClimaActual();

    setState(() {
      _detalleBackend = dataAtraccion;
      _clima = dataClima;
      _cargando = false;
    });
  }

  HorarioAtencion _obtenerHorarioActividad(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('sand') || t.contains('huacachina') || t.contains('buggy')) {
      return HorarioAtencion.paraHuacachina();
    } else if (t.contains('ballesta')) {
      return HorarioAtencion.paraIslasBallestas();
    } else if (t.contains('reserva')) {
      return HorarioAtencion.paraReservaParacas();
    } else if (t.contains('vino') || t.contains('bodega')) {
      return HorarioAtencion.paraVinedos();
    }
    return HorarioAtencion.noConfirmado();
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    final nombre = _detalleBackend?['name'] ?? widget.titulo;
    final distrito = _detalleBackend?['district'] ?? widget.subtitulo;
    final descripcion = _detalleBackend?['description'] ?? '';

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Carrusel de imágenes
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 320,
                          width: double.infinity,
                          child: PageView.builder(
                            itemCount: widget.imagenes.length,
                            onPageChanged: (index) {
                              setState(() => _paginaActual = index);
                            },
                            itemBuilder: (context, index) {
                              return Image.network(
                                widget.imagenes[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[400],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        IgnorePointer(
                          child: Container(
                            height: 320,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Ver seguimiento del destino',
                                      icon: const Icon(
                                        Icons.timeline,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PantallaSeguimientoDestino(
                                                  nombreDestinoInicial:
                                                      distrito,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                    ValueListenableBuilder(
                                      valueListenable: listaFavoritos,
                                      builder: (context, favoritos, child) {
                                        final esFav = favoritos.any(
                                          (e) => e['titulo'] == nombre,
                                        );
                                        return IconButton(
                                          icon: Icon(
                                            esFav
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                          onPressed: () {
                                            toggleFavorito({
                                              'id': widget.id,
                                              'titulo': nombre,
                                              'subtitulo': distrito,
                                              'imagen': widget.imagenes.first,
                                              'imagenes_detalle':
                                                  widget.imagenes,
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre.replaceAll('\n', ' '),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    distrito,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 15,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              widget.imagenes.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: _paginaActual == index ? 12 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _paginaActual == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Alerta activa (si existe)
                  ValueListenableBuilder<List<AlertaClima>>(
                    valueListenable: _alertasService.alertasNotifier,
                    builder: (context, alertas, _) {
                      final activa = alertas.where((a) {
                        final actLimpia = a.actividad
                            .replaceAll('\n', ' ')
                            .trim()
                            .toLowerCase();
                        final titLimpio = nombre
                            .replaceAll('\n', ' ')
                            .trim()
                            .toLowerCase();
                        return a.activa &&
                            (actLimpia == titLimpio ||
                                titLimpio.contains(actLimpia) ||
                                actLimpia.contains(titLimpio));
                      }).toList();

                      if (activa.isEmpty) return const SizedBox.shrink();

                      final alerta = activa.first;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: alerta.nivelRiesgo.colorFondo,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: alerta.nivelRiesgo.color,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(15),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PantallaDetalleAlerta(alerta: alerta),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      alerta.nivelRiesgo.icono,
                                      color: alerta.nivelRiesgo.color,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      alerta.nivelRiesgo.color,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  alerta.nivelRiesgo.etiqueta
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'Alerta Climática',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppColores.marronOscuro,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            alerta.titulo,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: alerta.nivelRiesgo.color,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${alerta.motivoCambio.split('.').first}. Toca para ver más.',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColores.marronOscuro,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: AppColores.grisTexto,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // 3. Descripción real
                  if (descripcion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sobre esta actividad',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorTexto,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            descripcion,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorTextoSecundario,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 4. Recomendación para hoy
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recomendación para hoy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorTexto,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PantallaDetalleDia(
                                  idActividad: widget.id, // 👈 AQUÍ EL ID
                                  tituloActividad: nombre,
                                  imagenActividad: widget.imagenes.first,
                                  fecha: 'Hoy',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorTarjeta,
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
                              children: [
                                Container(
                                  width: 55,
                                  height: 55,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFF3E0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '😊',
                                      style: TextStyle(fontSize: 30),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Excelente',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorTexto,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Condiciones ideales para disfrutar esta actividad.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorTextoSecundario,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: colorTextoSecundario,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Horarios de atención
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TarjetaHorariosAtencion(
                      horario: _obtenerHorarioActividad(nombre),
                      tituloDestino: nombre.replaceAll('\n', ' '),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. Seguimiento del destino
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorTarjeta,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColores.arenaFondo,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.timeline,
                              color: AppColores.marronOscuro,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Seguimiento de $distrito',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colorTexto,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Historial de cambios climáticos y aptitud de actividades.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorTextoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_forward,
                              color: AppColores.naranjaBoton,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PantallaSeguimientoDestino(
                                        nombreDestinoInicial: distrito,
                                      ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 7. Factores estadísticos
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Factores estadísticos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorTexto,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: colorTarjeta,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _FilaFactor(
                                icono: Icons.thermostat,
                                nombre: 'Temperatura',
                                valor: _clima != null
                                    ? '${(_clima!['temperatura_actual'] as num).round()}°C'
                                    : '--',
                                colorTexto: colorTexto,
                                colorTextoSecundario: colorTextoSecundario,
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: colorTextoSecundario.withOpacity(0.2),
                              ),
                              _FilaFactor(
                                icono: Icons.air,
                                nombre: 'Viento',
                                valor: _clima != null
                                    ? '${(_clima!['velocidad_viento'] as num).round()} km/h'
                                    : '--',
                                colorTexto: colorTexto,
                                colorTextoSecundario: colorTextoSecundario,
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: colorTextoSecundario.withOpacity(0.2),
                              ),
                              _FilaFactor(
                                icono: Icons.cloud_outlined,
                                nombre: 'Nubosidad',
                                valor: _clima != null
                                    ? '${(_clima!['humedad'] as num).round()}%'
                                    : '--',
                                colorTexto: colorTexto,
                                colorTextoSecundario: colorTextoSecundario,
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

class _FilaFactor extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final String valor;
  final Color colorTexto;
  final Color colorTextoSecundario;

  const _FilaFactor({
    required this.icono,
    required this.nombre,
    required this.valor,
    required this.colorTexto,
    required this.colorTextoSecundario,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, color: colorTexto, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: TextStyle(fontSize: 14, color: colorTexto),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 14, color: colorTextoSecundario),
        ],
      ),
    );
  }
}
