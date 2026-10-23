import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../config/favoritos_manager.dart';
import '../services/alertas_service.dart';
import '../models/alerta_modelo.dart';
import '../models/horario_modelo.dart';
import '../widgets/tarjeta_horarios_atencion.dart';
import 'pantalla_detalle_dia.dart';
import 'pantalla_detalle_alerta.dart';
import 'pantalla_seguimiento_destino.dart';

class PantallaDetalle extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final List<String> imagenes;

  const PantallaDetalle({
    super.key,
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

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {},
                      child: PageView.builder(
                        itemCount: widget.imagenes.length,
                        onPageChanged: (index) {
                          setState(() => _paginaActual = index);
                        },
                        physics: const BouncingScrollPhysics(),
                        padEnds: true,
                        itemBuilder: (context, index) {
                          return Image.asset(
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
                  ),

                  IgnorePointer(
                    child: Container(
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
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
                              // Botón rápido para seguimiento de este destino
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
                                        nombreDestinoInicial: widget.titulo,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // BOTÓN DE FAVORITO
                              ValueListenableBuilder(
                                valueListenable: listaFavoritos,
                                builder: (context, favoritos, child) {
                                  final esFav = favoritos.any(
                                    (e) => e['titulo'] == widget.titulo,
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
                                        'titulo': widget.titulo,
                                        'subtitulo': widget.subtitulo,
                                        'imagen': widget.imagenes.first,
                                        'imagenes_detalle': widget.imagenes,
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
                          widget.titulo.replaceAll('\n', ' '),
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
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              widget.subtitulo,
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
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _paginaActual == index ? 12 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _paginaActual == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
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

            // ALERTA ACTIVA SI EXISTE PARA ESTA ACTIVIDAD
            ValueListenableBuilder<List<AlertaClima>>(
              valueListenable: _alertasService.alertasNotifier,
              builder: (context, alertas, _) {
                final activa = alertas.where((a) {
                  final actLimpia = a.actividad.replaceAll('\n', ' ').trim().toLowerCase();
                  final titLimpio = widget.titulo.replaceAll('\n', ' ').trim().toLowerCase();
                  return a.activa && (actLimpia == titLimpio || titLimpio.contains(actLimpia) || actLimpia.contains(titLimpio));
                }).toList();

                if (activa.isEmpty) return const SizedBox.shrink();

                final alerta = activa.first;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: alerta.nivelRiesgo.colorFondo,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: alerta.nivelRiesgo.color, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
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
                              builder: (context) => PantallaDetalleAlerta(alerta: alerta),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(alerta.nivelRiesgo.icono, color: alerta.nivelRiesgo.color, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: alerta.nivelRiesgo.color,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            alerta.nivelRiesgo.etiqueta.toUpperCase(),
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
                                            color: AppColores.marronOscuro,
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
                                      '${alerta.motivoCambio.split('.').first}. Toca para ver "¿Por qué cambió?" y alternativas.',
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
                              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColores.grisTexto),
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
                            tituloActividad: widget.titulo,
                            imagenActividad: widget.imagenes.first,
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
                            color: Colors.black.withValues(alpha: 0.05),
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
                              child: Text('😊', style: TextStyle(fontSize: 30)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  'Condiciones ideales para disfrutar estas actividades.',
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

            // Horarios de atención y días disponibles (Req 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TarjetaHorariosAtencion(
                horario: _obtenerHorarioActividad(widget.titulo),
                tituloDestino: widget.titulo.replaceAll('\n', ' '),
              ),
            ),

            const SizedBox(height: 20),

            // Acceso al Seguimiento del Destino
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                      child: const Icon(Icons.timeline, color: AppColores.marronOscuro, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seguimiento de ${widget.subtitulo}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Historial de cambios climáticos y aptitud de actividades.',
                            style: TextStyle(fontSize: 11, color: AppColores.grisTexto),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: AppColores.naranjaBoton),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PantallaSeguimientoDestino(
                              nombreDestinoInicial: widget.titulo,
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
                          color: Colors.black.withValues(alpha: 0.05),
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
                          valor: '28°C',
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
                          valor: '15 km/h',
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
                          valor: '10%',
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

