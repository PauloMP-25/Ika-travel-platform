import 'package:flutter/material.dart';
import '../config/tema.dart';
import '../models/seguimiento_modelo.dart';
import '../services/seguimiento_service.dart';
import '../services/alertas_service.dart';
import 'pantalla_detalle_alerta.dart';

/// Pantalla de Seguimiento y Monitoreo de Destino (Requerimiento 14)
class PantallaSeguimientoDestino extends StatefulWidget {
  final String? nombreDestinoInicial;

  const PantallaSeguimientoDestino({
    super.key,
    this.nombreDestinoInicial,
  });

  @override
  State<PantallaSeguimientoDestino> createState() =>
      _PantallaSeguimientoDestinoState();
}

class _PantallaSeguimientoDestinoState
    extends State<PantallaSeguimientoDestino> {
  final SeguimientoService _seguimientoService = SeguimientoService();
  final AlertasService _alertasService = AlertasService();

  late String _destinoSeleccionadoId;
  int _tabSeleccionado = 0;

  @override
  void initState() {
    super.initState();
    final destinos = _seguimientoService.destinosNotifier.value;
    if (widget.nombreDestinoInicial != null && destinos.isNotEmpty) {
      final inicial = _seguimientoService
          .obtenerPorNombre(widget.nombreDestinoInicial!);
      _destinoSeleccionadoId = inicial?.id ?? destinos.first.id;
    } else {
      _destinoSeleccionadoId =
          destinos.isNotEmpty ? destinos.first.id : 'huacachina';
    }
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
      return 'Hace ${hoy.difference(dt).inDays} días, $hora:$minuto';
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
              icon: const Icon(Icons.arrow_back, color: AppColores.marronOscuro),
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
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Selector de Destino (Huacachina, Paracas, Ica)
                _buildSelectorDestinos(destinos),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner de Demostración Mock
                      _buildBannerMock(),

                      const SizedBox(height: 14),

                      // 2. Tarjeta de Estado Actual y Última Actualización
                      _buildTarjetaEstadoActual(destinoActual),

                      const SizedBox(height: 16),

                      // 3. Condiciones Relevantes para Actividades Disponibles
                      _buildCondicionesActividades(destinoActual),

                      const SizedBox(height: 20),

                      // 4. Historial Cronológico de Cambios (Antes vs Después)
                      _buildHistorialCambios(destinoActual),

                      const SizedBox(height: 20),

                      // 5. Alertas Vinculadas con Acceso al Detalle ("¿Por qué cambió?")
                      _buildAlertasRelacionadas(destinoActual),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerMock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_sync_outlined, color: Color(0xFF2E7D32), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Monitoreo ambiental y condiciones climáticas actualizadas en tiempo real.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1B5E20),
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
                if (val) {
                  setState(() => _destinoSeleccionadoId = dest.id);
                }
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
                            const Icon(Icons.update,
                                size: 14, color: AppColores.naranjaBoton),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Actualizado: ${_formatearFechaHora(destino.ultimaActualizacion)}',
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

              // Diagnóstico general del estado
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColores.arenaFondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColores.marronOscuro, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        destino.estadoGeneral,
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

              // Grilla de condiciones actuales del destino
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _itemMetricaChip(Icons.thermostat, 'Temperatura', destino.temperaturaActual),
                  _itemMetricaChip(Icons.air, 'Viento', destino.vientoActual),
                  _itemMetricaChip(Icons.water_drop, 'Humedad', destino.humedadActual),
                  _itemMetricaChip(Icons.wb_sunny, 'UV', destino.uvActual),
                ],
              ),

              const SizedBox(height: 14),

              // Botón de seguir destino
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: loSigue ? const Color(0xFFC62828) : AppColores.marronOscuro,
                    side: BorderSide(
                      color: loSigue ? const Color(0xFFC62828) : AppColores.marronOscuro,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(loSigue ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, size: 18),
                  label: Text(loSigue ? 'Dejar de seguir alertas de este destino' : 'Seguir y recibir alertas de este destino'),
                  onPressed: () {
                    _alertasService.toggleSeguirDestino(destino.nombre);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loSigue
                              ? 'Dejaste de seguir las alertas de ${destino.nombre}'
                              : 'Ahora sigues ${destino.nombre}. Recibirás alertas sobre sus condiciones.',
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
      children: [
        Icon(icono, size: 20, color: AppColores.naranjaBoton),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: const TextStyle(fontSize: 11, color: AppColores.grisTexto),
        ),
        Text(
          valor.split(' ').first,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColores.marronOscuro,
          ),
        ),
      ],
    );
  }

  /// Condiciones relevantes para las actividades disponibles (Req 14)
  Widget _buildCondicionesActividades(DestinoSeguimiento destino) {
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
        const Text(
          'Semáforo de aptitud operativa según las condiciones climáticas del momento',
          style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
        ),
        const SizedBox(height: 10),
        ...destino.actividadesAptitud.map((apt) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: apt.estado.color.withValues(alpha: 0.3)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        style: const TextStyle(fontSize: 12, color: AppColores.marronOscuro),
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

  /// Historial cronológico de cambios (Valores anteriores y actuales) (Req 14)
  Widget _buildHistorialCambios(DestinoSeguimiento destino) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial cronológico de cambios',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColores.marronOscuro,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bitácora de fluctuaciones registradas en este destino turístico',
          style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
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
          child: Column(
            children: destino.historialCambios.map((reg) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.only(bottom: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.8),
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
                            reg.parametroModificado,
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
                          _formatearFechaHora(reg.fechaHora),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColores.grisTexto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Valores anteriores y actuales (Wrap responsivo sin overflow)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Anterior: ${reg.valorAnterior}',
                            style: const TextStyle(fontSize: 11, color: AppColores.grisTexto),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColores.naranjaBoton),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Actual: ${reg.valorActual}',
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
                      reg.resumenImpacto,
                      style: const TextStyle(fontSize: 12, color: AppColores.marronOscuro),
                    ),
                    if (reg.alertaIdAsociada != null) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          final alerta = _alertasService.obtenerAlertaPorId(reg.alertaIdAsociada!);
                          if (alerta != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PantallaDetalleAlerta(alerta: alerta),
                              ),
                            );
                          }
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.open_in_new, size: 13, color: AppColores.naranjaBoton),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Ver detalle de la alerta ("¿Por qué cambió?")',
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

  /// Alertas relacionadas con el destino (Req 14)
  Widget _buildAlertasRelacionadas(DestinoSeguimiento destino) {
    final todas = _alertasService.alertasNotifier.value;
    final alertasDestino = todas
        .where((a) => a.destino.toLowerCase().contains(destino.nombre.toLowerCase().split(' ').first))
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
                    child: Icon(alerta.nivelRiesgo.icono, color: alerta.nivelRiesgo.color, size: 20),
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
                    '${alerta.actividad.replaceAll('\n', ' ')} • ${_formatearFechaHora(alerta.fechaHora)}',
                    style: const TextStyle(fontSize: 11, color: AppColores.grisTexto),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColores.grisTexto),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantallaDetalleAlerta(alerta: alerta),
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
