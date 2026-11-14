import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/alerta_modelo.dart';
import 'pantalla_seguimiento_destino.dart';

class PantallaDetalleAlerta extends StatelessWidget {
  final AlertaClima alerta;

  const PantallaDetalleAlerta({super.key, required this.alerta});

  String _formatearFechaHora(BuildContext context, DateTime dt) {
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    return '${context.tr('hoy')}, $hora:$minuto hrs';
  }

  bool get _tieneCondicionesReales {
    // El backend no envía condicionAnterior ni condicionActual.
    // Si los valores siguen siendo placeholders ('--'), no los mostramos.
    return !_esPlaceholder(alerta.condicionActual.estadoCielo) &&
        !_esPlaceholder(alerta.condicionAnterior.estadoCielo);
  }

  bool _esPlaceholder(String valor) {
    return valor.trim() == '--' || valor.trim().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final colorFondo = TemaApp.fondo(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorTarjeta,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorTexto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('detalle_alerta'),
          style: TextStyle(
            color: colorTexto,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('ver_seguimiento_destino'),
            icon: const Icon(Icons.timeline, color: AppColores.naranjaBoton),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PantallaSeguimientoDestino(
                    nombreDestinoInicial: alerta.destino,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _buildEncabezadoAlerta(
              context,
              colorTarjeta,
              colorTexto,
              colorTextoSecundario,
            ),
            const SizedBox(height: 18),
            _buildTarjetaCriterioRiesgo(context, colorTexto),
            const SizedBox(height: 18),
            if (_tieneCondicionesReales) ...[
              _buildComparativaCondiciones(
                context,
                colorTarjeta,
                colorTexto,
                colorTextoSecundario,
              ),
              const SizedBox(height: 18),
            ],
            _buildMotivoEImpacto(context, colorTarjeta, colorTexto),
            if (alerta.recomendacionesSeguridad.isNotEmpty) ...[
              const SizedBox(height: 18),
              _buildRecomendacionesSeguridad(context, colorTarjeta, colorTexto),
            ],
            const SizedBox(height: 24),
            _buildBotonSeguimientoDestino(context),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncabezadoAlerta(
    BuildContext context,
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorTarjeta,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TemaApp.fondo(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 14, color: colorTexto),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              alerta.destino,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: colorTexto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alerta.titulo,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: alerta.nivelRiesgo.colorFondo,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: alerta.nivelRiesgo.color,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      alerta.nivelRiesgo.icono,
                      size: 16,
                      color: alerta.nivelRiesgo.color,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        alerta.nivelRiesgo.etiqueta,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: alerta.nivelRiesgo.color,
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
            color: colorTextoSecundario.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time, size: 15, color: colorTextoSecundario),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${context.tr('detectado')}: ${_formatearFechaHora(context, alerta.fechaHora)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorTextoSecundario,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (alerta.activa)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.tr('alerta_activa'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaCriterioRiesgo(BuildContext context, Color colorTexto) {
    String criterio = '';
    switch (alerta.nivelRiesgo) {
      case NivelRiesgo.informativo:
        criterio = context.tr('criterio_informativo');
        break;
      case NivelRiesgo.precaucion:
        criterio = context.tr('criterio_precaucion');
        break;
      case NivelRiesgo.alto:
        criterio = context.tr('criterio_alto');
        break;
      case NivelRiesgo.critico:
        criterio = context.tr('criterio_critico');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alerta.nivelRiesgo.colorFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alerta.nivelRiesgo.color.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            alerta.nivelRiesgo.icono,
            color: alerta.nivelRiesgo.color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('criterio_clasificacion')}: ${alerta.nivelRiesgo.etiqueta}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: alerta.nivelRiesgo.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  criterio,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorTexto,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparativaCondiciones(
    BuildContext context,
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('comparativa_condiciones'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorTexto,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('comparativa_msg'),
          style: TextStyle(fontSize: 12, color: colorTextoSecundario),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTarjetaCondicionSnapshot(
                context,
                titulo: context.tr('condicion_anterior'),
                colorBorde: Colors.grey.shade400,
                fondo: colorTarjeta,
                condicion: alerta.condicionAnterior,
                esActual: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTarjetaCondicionSnapshot(
                context,
                titulo: context.tr('condicion_actual'),
                colorBorde: alerta.nivelRiesgo.color,
                fondo: colorTarjeta,
                condicion: alerta.condicionActual,
                esActual: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTarjetaCondicionSnapshot(
    BuildContext context, {
    required String titulo,
    required Color colorBorde,
    required Color fondo,
    required CondicionClima condicion,
    required bool esActual,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorBorde, width: esActual ? 1.8 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: esActual
                  ? alerta.nivelRiesgo.colorFondo
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: esActual
                    ? alerta.nivelRiesgo.color
                    : TemaApp.texto(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            condicion.estadoCielo,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: TemaApp.texto(context),
            ),
          ),
          const SizedBox(height: 8),
          _itemDatoClima(
            context,
            Icons.thermostat,
            context.tr('temperatura'),
            condicion.temperatura,
            esActual,
          ),
          _itemDatoClima(
            context,
            Icons.air,
            context.tr('viento'),
            condicion.velocidadViento,
            esActual,
          ),
          _itemDatoClima(
            context,
            Icons.water_drop_outlined,
            context.tr('lluvia'),
            condicion.probabilidadLluvia,
            esActual,
          ),
          _itemDatoClima(
            context,
            Icons.wb_sunny_outlined,
            context.tr('uv'),
            condicion.indiceUv,
            esActual,
          ),
          if (condicion.estadoMar != 'No aplica' &&
              !_esPlaceholder(condicion.estadoMar))
            _itemDatoClima(
              context,
              Icons.waves,
              context.tr('mar'),
              condicion.estadoMar,
              esActual,
            ),
        ],
      ),
    );
  }

  Widget _itemDatoClima(
    BuildContext context,
    IconData icono,
    String etiqueta,
    String valor,
    bool esActual,
  ) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            icono,
            size: 14,
            color: esActual ? AppColores.naranjaBoton : colorTextoSecundario,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 11, color: colorTextoSecundario),
            ),
          ),
          Flexible(
            child: Text(
              valor,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: esActual ? FontWeight.bold : FontWeight.w500,
                color: colorTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivoEImpacto(
    BuildContext context,
    Color colorTarjeta,
    Color colorTexto,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TemaApp.fondo(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.help_outline, color: colorTexto, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('por_que_cambio'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alerta.motivoCambio,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorTexto,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (alerta.impactoActividad.trim().isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.5),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.insights,
                    color: AppColores.naranjaBoton,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('impacto_esperado'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorTexto,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alerta.impactoActividad,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorTexto,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecomendacionesSeguridad(
    BuildContext context,
    Color colorTarjeta,
    Color colorTexto,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFF2E7D32),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('recomendaciones_seguridad'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...alerta.recomendacionesSeguridad.map((rec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 14, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorTexto,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBotonSeguimientoDestino(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.marronOscuro,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: const Icon(Icons.timeline_outlined),
        label: Text(
          '${context.tr('seguimiento_e_historial_de')} ${alerta.destino}',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaSeguimientoDestino(
                nombreDestinoInicial: alerta.destino,
              ),
            ),
          );
        },
      ),
    );
  }
}
