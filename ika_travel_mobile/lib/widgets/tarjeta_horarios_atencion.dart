import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/horario_modelo.dart';

/// Widget reutilizable para mostrar horarios de atención y días disponibles (Requerimiento 3)
/// Usado de manera consistente en PantallaDetalle y PantallaDetalleAlternativa.
class TarjetaHorariosAtencion extends StatefulWidget {
  final HorarioAtencion horario;
  final String tituloDestino;

  const TarjetaHorariosAtencion({
    super.key,
    required this.horario,
    required this.tituloDestino,
  });

  @override
  State<TarjetaHorariosAtencion> createState() =>
      _TarjetaHorariosAtencionState();
}

class _TarjetaHorariosAtencionState extends State<TarjetaHorariosAtencion> {
  bool _mostrarDetallePorDia = false;

  Color _colorEstadoVerificacion(String estado) {
    if (estado.toLowerCase().contains('verificado') ||
        estado.toLowerCase().contains('oficial')) {
      return const Color(0xFF2E7D32); // Verde
    } else if (estado.toLowerCase().contains('referencial')) {
      return const Color(0xFFE65100); // Naranja / Ámbar
    } else {
      return const Color(0xFF757575); // Gris
    }
  }

  Color _fondoEstadoVerificacion(String estado) {
    if (estado.toLowerCase().contains('verificado') ||
        estado.toLowerCase().contains('oficial')) {
      return const Color(0xFFE8F5E9);
    } else if (estado.toLowerCase().contains('referencial')) {
      return const Color(0xFFFFF3E0);
    } else {
      return const Color(0xFFF5F5F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horario = widget.horario;
    final colorBadge = _colorEstadoVerificacion(horario.estadoVerificacion);
    final fondoBadge = _fondoEstadoVerificacion(horario.estadoVerificacion);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Título y Badge de Verificación
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👇 EXPANDED PARA QUE EL TÍTULO NO SE DESBORDE
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppColores.marronOscuro,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Horarios de Atención',
                          overflow: TextOverflow
                              .ellipsis, // Corta con "..." si es muy largo
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColores.marronOscuro,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Badge de verificación
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fondoBadge,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorBadge.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        horario.esVerificado
                            ? Icons.verified
                            : Icons.info_outline,
                        size: 13,
                        color: colorBadge,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        horario.estadoVerificacion,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorBadge,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),

            // Días disponibles
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColores.naranjaBoton,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Días disponibles',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColores.grisTexto,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        horario.diasSemana,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Horario general
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.access_time_filled,
                  size: 18,
                  color: AppColores.naranjaBoton,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Horario de visita / operación',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColores.grisTexto,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        horario.horarioGeneral,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Desglose de horarios por día si existen
            if (horario.horariosPorDia.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _mostrarDetallePorDia = !_mostrarDetallePorDia;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        _mostrarDetallePorDia
                            ? 'Ocultar horarios específicos por día'
                            : 'Ver horarios específicos por día (${horario.horariosPorDia.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColores.naranjaBoton,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _mostrarDetallePorDia
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColores.naranjaBoton,
                      ),
                    ],
                  ),
                ),
              ),
              if (_mostrarDetallePorDia) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColores.arenaFondo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: horario.horariosPorDia.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColores.marronOscuro,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.dia,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColores.marronOscuro,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.horario,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColores.marronOscuro,
                                    ),
                                  ),
                                  if (item.nota != null)
                                    Text(
                                      item.nota!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColores.grisTexto,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],

            // Observaciones relevantes
            if (horario.observaciones.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 0.8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.announcement_outlined,
                      size: 16,
                      color: AppColores.marronOscuro,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Observaciones importantes:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            horario.observaciones,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColores.marronOscuro,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
