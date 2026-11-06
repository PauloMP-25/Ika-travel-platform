import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/horario_modelo.dart';

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
      return const Color(0xFF2E7D32);
    } else if (estado.toLowerCase().contains('referencial')) {
      return const Color(0xFFE65100);
    } else {
      return const Color(0xFF757575);
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
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorFondo = TemaApp.fondo(context);

    final colorBadge = _colorEstadoVerificacion(horario.estadoVerificacion);
    final fondoBadge = _fondoEstadoVerificacion(horario.estadoVerificacion);

    return Container(
      decoration: BoxDecoration(
        color: colorTarjeta,
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
            // Cabecera ajustada para evitar overflow
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: colorTexto, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('horarios_atencion'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorTexto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                      Flexible(
                        child: Text(
                          horario.estadoVerificacion,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorBadge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 0.5,
              color: colorTextoSecundario.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),

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
                      Text(
                        context.tr('dias_disponibles'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorTextoSecundario,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        horario.diasSemana,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorTexto,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

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
                      Text(
                        context.tr('horario_visita_operacion'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorTextoSecundario,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        horario.horarioGeneral,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorTexto,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

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
                      Expanded(
                        child: Text(
                          _mostrarDetallePorDia
                              ? context.tr('ocultar_horarios_dia')
                              : '${context.tr('ver_horarios_dia')} (${horario.horariosPorDia.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColores.naranjaBoton,
                          ),
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
                    color: colorFondo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: horario.horariosPorDia.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.dia,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorTexto,
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
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorTexto,
                                    ),
                                  ),
                                  if (item.nota != null)
                                    Text(
                                      item.nota!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorTextoSecundario,
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

            if (horario.observaciones.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorFondo,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorTextoSecundario.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.announcement_outlined,
                      size: 16,
                      color: colorTexto,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('observaciones_importantes'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorTexto,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            horario.observaciones,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorTexto,
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
