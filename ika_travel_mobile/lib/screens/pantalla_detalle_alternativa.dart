import 'package:flutter/material.dart';
import '../config/tema.dart';
import '../config/navegacion_service.dart';
import '../models/alternativa_modelo.dart';
import '../models/horario_modelo.dart';
import '../widgets/tarjeta_horarios_atencion.dart';
import 'pantalla_seguimiento_destino.dart';

/// Pantalla de Detalle Independiente de la Alternativa Recomendada (Requerimiento 1)
class PantallaDetalleAlternativa extends StatelessWidget {
  final AlternativaRecomendada alternativa;

  const PantallaDetalleAlternativa({
    super.key,
    required this.alternativa,
  });

  @override
  Widget build(BuildContext context) {
    final horario = alternativa.horarioAtencion ??
        (alternativa.tituloActividad.toLowerCase().contains('vino')
            ? HorarioAtencion.paraVinedos()
            : alternativa.tituloActividad.toLowerCase().contains('ballesta')
                ? HorarioAtencion.paraIslasBallestas()
                : alternativa.tituloActividad.toLowerCase().contains('reserva')
                    ? HorarioAtencion.paraReservaParacas()
                    : alternativa.tituloActividad.toLowerCase().contains('sand') ||
                            alternativa.tituloActividad.toLowerCase().contains('huacachina')
                        ? HorarioAtencion.paraHuacachina()
                        : HorarioAtencion.noConfirmado());

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
          'Alternativa Recomendada',
          style: TextStyle(
            color: AppColores.marronOscuro,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ver en el mapa de Ika Travel',
            icon: const Icon(Icons.map_outlined, color: AppColores.naranjaBoton),
            onPressed: () {
              // Navega a la sección principal del mapa conservando la barra inferior
              NavegacionService.irAMapa(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Imagen de cabecera con Badge de Tipo de Alternativa
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
                      child: const Icon(Icons.image, size: 50, color: Colors.white),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          const Icon(Icons.location_on, color: Colors.white70, size: 16),
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
                  // 2. Por qué se recomienda esta alternativa (Req 1)
                  _buildTarjetaMotivoRecomendacion(),

                  const SizedBox(height: 18),

                  // 3. Condiciones actuales disponibles del lugar (Req 1)
                  _buildTarjetaCondicionesActuales(),

                  const SizedBox(height: 18),

                  // 4. Información del lugar (Req 1)
                  _buildTarjetaInformacionLugar(),

                  const SizedBox(height: 18),

                  // 5. Horarios de atención y días disponibles (Req 1 y 3)
                  TarjetaHorariosAtencion(
                    horario: horario,
                    tituloDestino: alternativa.tituloActividad,
                  ),

                  const SizedBox(height: 22),

                  // 6. Acciones: Ver en el mapa o consultar seguimiento (Req 1 y 2)
                  _buildBotonesAccion(context),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta con el motivo concreto de la recomendación y justificación climática
  Widget _buildTarjetaMotivoRecomendacion() {
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
          const Row(
            children: [
              Icon(Icons.recommend, color: Color(0xFFE65100), size: 22),
              SizedBox(width: 8),
              Text(
                '¿Por qué se recomienda?',
                style: TextStyle(
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
                const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Condición que justifica el cambio:',
                        style: TextStyle(
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
                    'Ventana horaria ideal: ${alternativa.mejorHorarioSugerido}',
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

  /// Condiciones actuales disponibles
  Widget _buildTarjetaCondicionesActuales() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Condiciones Actuales Disponibles',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColores.marronOscuro,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Estado meteorológico en la zona de esta alternativa',
            style: TextStyle(fontSize: 11, color: AppColores.grisTexto),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _itemClimaChip(Icons.thermostat, 'Temperatura', alternativa.temperaturaActual),
              _itemClimaChip(Icons.air, 'Viento', alternativa.vientoActual),
              _itemClimaChip(Icons.wb_sunny_outlined, 'Estado', alternativa.estadoClima),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemClimaChip(IconData icono, String etiqueta, String valor) {
    return Column(
      children: [
        Icon(icono, color: AppColores.naranjaBoton, size: 22),
        const SizedBox(height: 4),
        Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColores.grisTexto)),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColores.marronOscuro,
          ),
        ),
      ],
    );
  }

  /// Información del lugar
  Widget _buildTarjetaInformacionLugar() {
    final descripcion = alternativa.descripcionLugar.isNotEmpty
        ? alternativa.descripcionLugar
        : 'Destino turístico con atractivos naturales y culturales destacados de la región Ica.';

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColores.marronOscuro, size: 20),
              SizedBox(width: 8),
              Text(
                'Información del Lugar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColores.marronOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            descripcion,
            style: const TextStyle(
              fontSize: 13,
              color: AppColores.marronOscuro,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Botones de acción: Ver en el mapa o consultar seguimiento
  Widget _buildBotonesAccion(BuildContext context) {
    return Column(
      children: [
        // Botón 1: Ver en el mapa (cumple Req 1 y 2 manteniendo navegación inferior)
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
            label: const Text('Ver en el Mapa de Ika Travel'),
            onPressed: () {
              // Navega directamente a la pestaña del mapa de la app principal conservando la barra inferior
              NavegacionService.irAMapa(context);
            },
          ),
        ),

        const SizedBox(height: 10),

        // Botón 2: Consultar seguimiento de este destino
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColores.marronOscuro,
              side: const BorderSide(color: AppColores.marronOscuro, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.timeline),
            label: Text(
              'Consultar Seguimiento de ${alternativa.destino}',
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
