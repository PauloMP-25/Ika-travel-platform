import 'package:flutter/material.dart';
import '../config/tema.dart';
import '../models/alerta_modelo.dart';
import '../models/alternativa_modelo.dart';
import '../services/recomendador_service.dart';
import 'pantalla_seguimiento_destino.dart';
import 'pantalla_detalle_alternativa.dart';

/// Pantalla de Detalle de Alerta ("¿Por qué cambió?" y "Alternativas Recomendadas")
/// Cumple con los requerimientos 12 y 13.
class PantallaDetalleAlerta extends StatelessWidget {
  final AlertaClima alerta;

  const PantallaDetalleAlerta({
    super.key,
    required this.alerta,
  });

  String _formatearFechaHora(DateTime dt) {
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    return 'Hoy, $hora:$minuto hrs';
  }

  @override
  Widget build(BuildContext context) {
    final alternativas =
        RecomendadorService().obtenerAlternativasParaAlerta(alerta);

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
          'Detalle de la Alerta',
          style: TextStyle(
            color: AppColores.marronOscuro,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ver seguimiento del destino',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Banner de Datos de Demostración (Requisito técnico)
            _buildBannerMock(),

            const SizedBox(height: 14),

            // 2. Encabezado con Destino, Actividad y Nivel de Riesgo (Req 12)
            _buildEncabezadoAlerta(),

            const SizedBox(height: 18),

            // 3. Tarjeta de Criterio de Riesgo / Importancia (Req 12)
            _buildTarjetaCriterioRiesgo(),

            const SizedBox(height: 18),

            // 4. Comparativa: Condición Anterior vs. Condición Actual (Req 12)
            _buildComparativaCondiciones(),

            const SizedBox(height: 18),

            // 5. Motivo Concreto e Impacto Esperado (Req 12)
            _buildMotivoEImpacto(),

            const SizedBox(height: 18),

            // 6. Recomendaciones Prácticas de Seguridad (Req 12)
            _buildRecomendacionesSeguridad(),

            const SizedBox(height: 24),

            // 7. SECCIÓN DE ALTERNATIVAS RECOMENDADAS (Req 13)
            _buildSeccionAlternativas(context, alternativas),

            const SizedBox(height: 20),

            // 8. Botón para Monitoreo de Destino (Req 14)
            _buildBotonSeguimientoDestino(context),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// Banner identificando datos mock explícitamente
  Widget _buildBannerMock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: Color(0xFF1565C0), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo Demostración: Los datos climáticos corresponden a simulación representativa de Ica y Paracas.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Encabezado con actividad, destino, fecha y badge de riesgo
  Widget _buildEncabezadoAlerta() {
    return Container(
      padding: const EdgeInsets.all(18),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColores.arenaFondo,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColores.marronOscuro),
                          const SizedBox(width: 4),
                          Text(
                            alerta.destino,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alerta.actividad.replaceAll('\n', ' '),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: alerta.nivelRiesgo.colorFondo,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: alerta.nivelRiesgo.color, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(alerta.nivelRiesgo.icono, size: 16, color: alerta.nivelRiesgo.color),
                    const SizedBox(width: 6),
                    Text(
                      alerta.nivelRiesgo.etiqueta,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: alerta.nivelRiesgo.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 15, color: AppColores.grisTexto),
              const SizedBox(width: 6),
              Text(
                'Detectado: ${_formatearFechaHora(alerta.fechaHora)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColores.grisTexto,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (alerta.activa)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '● Alerta Activa',
                    style: TextStyle(
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

  /// Criterio del nivel de riesgo
  Widget _buildTarjetaCriterioRiesgo() {
    String criterio = '';
    switch (alerta.nivelRiesgo) {
      case NivelRiesgo.informativo:
        criterio =
            'Variación menor dentro de los rangos habituales de confort térmico y seguridad turística.';
        break;
      case NivelRiesgo.precaucion:
        criterio =
            'Condición que requiere equipo preventivo adicional (bloqueador, cortaviento, gafas) o atención especial.';
        break;
      case NivelRiesgo.alto:
        criterio =
            'Condición meteorológica desfavorable con ráfagas > 30 km/h o visibilidad restringida que compromete la estabilidad en deportes de aventura.';
        break;
      case NivelRiesgo.critico:
        criterio =
            'Peligro para la integridad física o restricción legal de autoridades (ej. bandera roja/cierre de puerto por oleaje de Capitanía).';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alerta.nivelRiesgo.colorFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alerta.nivelRiesgo.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alerta.nivelRiesgo.icono, color: alerta.nivelRiesgo.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Criterio de clasificación: ${alerta.nivelRiesgo.etiqueta}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: alerta.nivelRiesgo.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  criterio,
                  style: const TextStyle(fontSize: 12, color: AppColores.marronOscuro, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Comparativa visual de condiciones: ANTERIOR vs ACTUAL (Req 12)
  Widget _buildComparativaCondiciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comparativa de Condiciones',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColores.marronOscuro,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Valores registrados antes y después del cambio detectado',
          style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Condición Anterior
            Expanded(
              child: _buildTarjetaCondicionSnapshot(
                titulo: 'Condición Anterior',
                colorBorde: Colors.grey.shade400,
                fondo: Colors.white,
                condicion: alerta.condicionAnterior,
                esActual: false,
              ),
            ),
            const SizedBox(width: 10),
            // Condición Actual
            Expanded(
              child: _buildTarjetaCondicionSnapshot(
                titulo: 'Condición Actual',
                colorBorde: alerta.nivelRiesgo.color,
                fondo: Colors.white,
                condicion: alerta.condicionActual,
                esActual: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTarjetaCondicionSnapshot({
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
              color: esActual ? alerta.nivelRiesgo.colorFondo : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: esActual ? alerta.nivelRiesgo.color : AppColores.marronOscuro,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            condicion.estadoCielo,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColores.marronOscuro,
            ),
          ),
          const SizedBox(height: 8),
          _itemDatoClima(Icons.thermostat, 'Temperatura', condicion.temperatura, esActual),
          _itemDatoClima(Icons.air, 'Viento', condicion.velocidadViento, esActual),
          _itemDatoClima(Icons.water_drop_outlined, 'Lluvia', condicion.probabilidadLluvia, esActual),
          _itemDatoClima(Icons.wb_sunny_outlined, 'Índice UV', condicion.indiceUv, esActual),
          if (condicion.estadoMar != 'No aplica')
            _itemDatoClima(Icons.waves, 'Mar', condicion.estadoMar, esActual),
        ],
      ),
    );
  }

  Widget _itemDatoClima(IconData icono, String etiqueta, String valor, bool esActual) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 14, color: esActual ? AppColores.naranjaBoton : AppColores.grisTexto),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 11, color: AppColores.grisTexto),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 11,
              fontWeight: esActual ? FontWeight.bold : FontWeight.w500,
              color: AppColores.marronOscuro,
            ),
          ),
        ],
      ),
    );
  }

  /// Motivo concreto e Impacto esperado (Req 12)
  Widget _buildMotivoEImpacto() {
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
          // Motivo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColores.arenaFondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.help_outline, color: AppColores.marronOscuro, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Por qué cambió?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alerta.motivoCambio,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColores.marronOscuro,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 0.5),
          ),

          // Impacto en la actividad
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights, color: AppColores.naranjaBoton, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Impacto esperado en la actividad',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alerta.impactoActividad,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColores.marronOscuro,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Recomendaciones prácticas de seguridad (Req 12)
  Widget _buildRecomendacionesSeguridad() {
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
              Icon(Icons.shield_outlined, color: Color(0xFF2E7D32), size: 22),
              SizedBox(width: 8),
              Text(
                'Recomendaciones prácticas de seguridad',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColores.marronOscuro,
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
                  const Text('✓ ',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                  Expanded(
                    child: Text(
                      rec,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColores.marronOscuro,
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

  /// Sección de alternativas recomendadas (Requerimiento 13)
  Widget _buildSeccionAlternativas(
      BuildContext context, List<AlternativaRecomendada> alternativas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Alternativas recomendadas',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColores.marronOscuro,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${alternativas.length} disponibles',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Actividades, destinos o ventanas horarias viables según las condiciones actuales',
          style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
        ),
        const SizedBox(height: 12),
        ...alternativas.map((alt) => _buildCardAlternativa(context, alt)),
      ],
    );
  }

  Widget _buildCardAlternativa(BuildContext context, AlternativaRecomendada alt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          // Imagen con etiqueta
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Stack(
              children: [
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: Image.asset(
                    alt.imagen,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
                Container(
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColores.naranjaBoton,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      alt.tipoAlternativa.etiqueta,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 14,
                  right: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alt.tituloActividad,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        alt.destino,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Motivo de la recomendación (Req 13)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.recommend, color: AppColores.naranjaBoton, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¿Por qué se recomienda esta alternativa?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alt.motivoRecomendacion,
                            style: const TextStyle(fontSize: 12, color: AppColores.marronOscuro),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Condiciones que justifican (Req 13)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Condiciones que la justifican:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alt.condicionesQueJustifican,
                            style: const TextStyle(fontSize: 12, color: AppColores.marronOscuro),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Mejor horario (Req 13)
                if (alt.mejorHorarioSugerido != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD54F)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Color(0xFFF57F17)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mejor horario estimado: ${alt.mejorHorarioSugerido}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Botón para ver detalle independiente de la alternativa (Req 1)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColores.marronOscuro,
                      side: const BorderSide(color: AppColores.marronOscuro),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Ver detalle de esta alternativa'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaDetalleAlternativa(
                            alternativa: alt,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Botón para ver seguimiento del destino (Req 14)
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
        label: Text('Seguimiento e Historial de ${alerta.destino}'),
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
