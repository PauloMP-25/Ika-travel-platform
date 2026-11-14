import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/navegacion_service.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/alternativa_modelo.dart';
import '../models/horario_modelo.dart';
import '../widgets/tarjeta_horarios_atencion.dart';
import 'pantalla_seguimiento_destino.dart';

class PantallaDetalleAlternativa extends StatelessWidget {
  final AlternativaRecomendada alternativa;

  const PantallaDetalleAlternativa({super.key, required this.alternativa});

  @override
  Widget build(BuildContext context) {
    final colorFondo = TemaApp.fondo(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    final horario =
        alternativa.horarioAtencion ??
        (alternativa.tituloActividad.toLowerCase().contains('vino')
            ? HorarioAtencion.paraVinedos()
            : alternativa.tituloActividad.toLowerCase().contains('ballesta')
            ? HorarioAtencion.paraIslasBallestas()
            : alternativa.tituloActividad.toLowerCase().contains('reserva')
            ? HorarioAtencion.paraReservaParacas()
            : alternativa.tituloActividad.toLowerCase().contains('sand') ||
                  alternativa.tituloActividad.toLowerCase().contains(
                    'huacachina',
                  )
            ? HorarioAtencion.paraHuacachina()
            : HorarioAtencion.noConfirmado());

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
          context.tr('alternativa_recomendada'),
          style: TextStyle(
            color: colorTexto,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('ver_en_mapa_tooltip'),
            icon: const Icon(
              Icons.map_outlined,
              color: AppColores.naranjaBoton,
            ),
            onPressed: () {
              NavegacionService.irAMapa(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Stack(
              children: [
                SizedBox(
                  height: 230,
                  width: double.infinity,
                  child: Image.asset(
                    alternativa.imagen,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade400,
                      child: const Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 230,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColores.naranjaBoton,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      alternativa.tipoAlternativa.etiqueta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alternativa.tituloActividad,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            alternativa.destino,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTarjetaMotivoRecomendacion(context),
                  const SizedBox(height: 18),
                  _buildTarjetaCondicionesActuales(context),
                  const SizedBox(height: 18),
                  _buildTarjetaInformacionLugar(context),
                  const SizedBox(height: 18),
                  TarjetaHorariosAtencion(
                    horario: horario,
                    tituloDestino: alternativa.tituloActividad,
                  ),
                  const SizedBox(height: 22),
                  _buildBotonesAccion(context),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTarjetaMotivoRecomendacion(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.recommend, color: Color(0xFFE65100), size: 22),
              const SizedBox(width: 8),
              Text(
                context.tr('por_que_se_recomienda'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alternativa.motivoRecomendacion,
            style: const TextStyle(
              fontSize: 13,
              color: AppColores.marronOscuro,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF2E7D32),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('condicion_justifica_cambio'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alternativa.condicionesQueJustifican,
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
          ),
          if (alternativa.mejorHorarioSugerido != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Color(0xFFE65100)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${context.tr('ventana_horaria_ideal')} ${alternativa.mejorHorarioSugerido}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTarjetaCondicionesActuales(BuildContext context) {
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

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
          Text(
            context.tr('condiciones_actuales_disponibles'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('estado_meteorologico_zona'),
            style: TextStyle(fontSize: 11, color: colorTextoSecundario),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _itemClimaChip(
                context,
                Icons.thermostat,
                context.tr('temperatura'),
                alternativa.temperaturaActual,
              ),
              _itemClimaChip(
                context,
                Icons.air,
                context.tr('viento'),
                alternativa.vientoActual,
              ),
              _itemClimaChip(
                context,
                Icons.wb_sunny_outlined,
                context.tr('estado'),
                alternativa.estadoClima,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemClimaChip(
    BuildContext context,
    IconData icono,
    String etiqueta,
    String valor,
  ) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return Column(
      children: [
        Icon(icono, color: AppColores.naranjaBoton, size: 22),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: TextStyle(fontSize: 11, color: colorTextoSecundario),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorTexto,
          ),
        ),
      ],
    );
  }

  Widget _buildTarjetaInformacionLugar(BuildContext context) {
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);

    final descripcion = alternativa.descripcionLugar.isNotEmpty
        ? alternativa.descripcionLugar
        : context.tr('descripcion_lugar_default');

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
              Icon(Icons.info_outline, color: colorTexto, size: 20),
              const SizedBox(width: 8),
              Text(
                context.tr('informacion_lugar'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorTexto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            descripcion,
            style: TextStyle(fontSize: 13, color: colorTexto, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    return Column(
      children: [
        SizedBox(
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
            icon: const Icon(Icons.map_outlined),
            label: Text(context.tr('ver_en_mapa_ika')),
            onPressed: () {
              NavegacionService.irAMapa(context);
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorTexto,
              side: BorderSide(color: colorTexto, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.timeline),
            label: Text(
              '${context.tr('consultar_seguimiento_de')} ${alternativa.destino}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PantallaSeguimientoDestino(
                    nombreDestinoInicial: alternativa.destino,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
