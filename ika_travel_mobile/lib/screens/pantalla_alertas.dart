import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/alerta_modelo.dart';
import '../services/alertas_service.dart';
import 'pantalla_configurar_alertas.dart';
import 'pantalla_detalle_alerta.dart';
import 'pantalla_seguimiento_destino.dart';

class PantallaAlertas extends StatefulWidget {
  const PantallaAlertas({super.key});

  @override
  State<PantallaAlertas> createState() => _PantallaAlertasState();
}

class _PantallaAlertasState extends State<PantallaAlertas> {
  int _opcionSeleccionada = 0;
  final AlertasService _alertasService = AlertasService();

  @override
  void initState() {
    super.initState();
    _alertasService.cargarDesdeBackend();
    _alertasService.cargarHistorial();
    _alertasService.cargarRecomendaciones();
  }

  String _formatearFechaHora(DateTime dt) {
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    final hoy = DateTime.now();
    if (dt.day == hoy.day && dt.month == hoy.month && dt.year == hoy.year) {
      return '${context.tr('hoy')}, $hora:$minuto';
    } else if (hoy.difference(dt).inDays <= 1) {
      return '${context.tr('ayer')}, $hora:$minuto';
    } else {
      return '${context.tr('hace')} ${hoy.difference(dt).inDays} ${context.tr('dias')}';
    }
  }

  Future<void> _refrescarAlertas() async {
    await _alertasService.cargarDesdeBackend();
    await _alertasService.cargarHistorial();
    await _alertasService.cargarRecomendaciones();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('alertas_actualizadas')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _marcarComoLeida(AlertaClima alerta) async {
    final ok = await _alertasService.marcarComoLeida(alerta.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('alerta_marcada_leida')
              : context.tr('error_marcar_leida'),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorFondo = TemaApp.fondo(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorTexto, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      context.tr('alertas_inteligentes'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: context.tr('refrescar'),
                        icon: _alertasService.cargando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColores.naranjaBoton,
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: AppColores.naranjaBoton,
                                size: 24,
                              ),
                        onPressed: _alertasService.cargando
                            ? null
                            : _refrescarAlertas,
                      ),
                      IconButton(
                        tooltip: context.tr('configuracion_alertas'),
                        icon: Icon(
                          Icons.settings_outlined,
                          color: colorTexto,
                          size: 24,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PantallaConfigurarAlertas(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: colorTarjeta,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _botonToggle(
                      context.tr('alertas'),
                      0,
                      colorTextoSecundario,
                    ),
                    _botonToggle(
                      context.tr('alternativas'),
                      1,
                      colorTextoSecundario,
                    ),
                    _botonToggle(
                      context.tr('historial'),
                      2,
                      colorTextoSecundario,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _opcionSeleccionada == 1
                  ? _buildVistaAlternativas(
                      colorTarjeta,
                      colorTexto,
                      colorTextoSecundario,
                    )
                  : _opcionSeleccionada == 2
                  ? _buildVistaHistorial(
                      colorFondo,
                      colorTarjeta,
                      colorTexto,
                      colorTextoSecundario,
                    )
                  : _buildVistaAlertasActivas(
                      colorFondo,
                      colorTarjeta,
                      colorTexto,
                      colorTextoSecundario,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaAlertasActivas(
    Color colorFondo,
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return ValueListenableBuilder<List<AlertaClima>>(
      valueListenable: _alertasService.alertasNotifier,
      builder: (context, alertas, _) {
        if (alertas.isEmpty &&
            _alertasService.ultimaActualizacion == null &&
            _alertasService.ultimoError == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColores.naranjaBoton),
          );
        }

        if (alertas.isEmpty) {
          return _buildEstadoVacio(
            icono: Icons.check_circle_outline,
            mensaje: context.tr('no_alertas_activas'),
            colorTextoSecundario: colorTextoSecundario,
            mostrarError: _alertasService.ultimoError != null,
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            if (alertas.any(
              (a) =>
                  a.nivelRiesgo == NivelRiesgo.alto ||
                  a.nivelRiesgo == NivelRiesgo.critico,
            ))
              GestureDetector(
                onTap: () {
                  setState(() => _opcionSeleccionada = 1);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.alt_route,
                        color: Color(0xFFE65100),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('condiciones_desfavorables'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFE65100),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ...alertas.map(
              (alerta) => _buildItemAlerta(
                context,
                alerta,
                colorTarjeta,
                colorFondo,
                colorTexto,
                colorTextoSecundario,
                esHistorial: false,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVistaHistorial(
    Color colorFondo,
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return ValueListenableBuilder<List<AlertaClima>>(
      valueListenable: _alertasService.historialNotifier,
      builder: (context, alertas, _) {
        if (alertas.isEmpty) {
          return _buildEstadoVacio(
            icono: Icons.history_toggle_off,
            mensaje: context.tr('no_historial'),
            colorTextoSecundario: colorTextoSecundario,
            mostrarError: false,
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: alertas
              .map(
                (alerta) => _buildItemAlerta(
                  context,
                  alerta,
                  colorTarjeta,
                  colorFondo,
                  colorTexto,
                  colorTextoSecundario,
                  esHistorial: true,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildEstadoVacio({
    required IconData icono,
    required String mensaje,
    required Color colorTextoSecundario,
    required bool mostrarError,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 56, color: colorTextoSecundario),
            const SizedBox(height: 10),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorTextoSecundario, fontSize: 14),
            ),
            if (mostrarError) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('sin_conexion_servidor'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVistaAlternativas(
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _alertasService.recomendacionesNotifier,
      builder: (context, recomendaciones, _) {
        if (recomendaciones.isEmpty) {
          return _buildEstadoVacio(
            icono: Icons.lightbulb_outline,
            mensaje: context.tr('no_recomendaciones'),
            colorTextoSecundario: colorTextoSecundario,
            mostrarError: false,
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('alternativas_msg'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1B5E20),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...recomendaciones.map(
              (json) => _buildTarjetaRecomendacionBackend(
                context,
                json,
                colorTarjeta,
                colorTexto,
                colorTextoSecundario,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTarjetaRecomendacionBackend(
    BuildContext context,
    Map<String, dynamic> json,
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    final nombre = (json['atractivo_nombre'] ?? '').toString();
    final score = (json['score'] as num?)?.toDouble() ?? 0.0;
    final nivel = (json['nivel'] ?? '').toString();
    final texto = (json['recommendation_text'] ?? '').toString();
    final consejos = (json['consejos'] as List<dynamic>?)?.cast<String>() ?? [];

    final colorScore = score >= 0.7
        ? const Color(0xFF2E7D32)
        : score >= 0.4
        ? const Color(0xFFE65100)
        : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Expanded(
                child: Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScore.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  nivel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScore,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star, size: 16, color: colorScore),
              const SizedBox(width: 4),
              Text(
                '${(score * 100).toStringAsFixed(0)}/100',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            texto,
            style: TextStyle(fontSize: 13, color: colorTexto, height: 1.4),
          ),
          if (consejos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: colorTextoSecundario.withValues(alpha: 0.2)),
            const SizedBox(height: 6),
            ...consejos.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorTextoSecundario,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemAlerta(
    BuildContext context,
    AlertaClima alerta,
    Color colorTarjeta,
    Color colorFondo,
    Color colorTexto,
    Color colorTextoSecundario, {
    required bool esHistorial,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PantallaDetalleAlerta(alerta: alerta),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: alerta.nivelRiesgo.colorFondo,
                      child: Icon(
                        alerta.nivelRiesgo.icono,
                        color: alerta.nivelRiesgo.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorFondo,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  alerta.destino,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colorTexto,
                                  ),
                                ),
                              ),
                              Text(
                                _formatearFechaHora(alerta.fechaHora),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorTextoSecundario,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alerta.titulo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: colorTexto,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alerta.actividad.replaceAll('\n', ' '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.naranjaBoton,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  alerta.motivoCambio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorTexto,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: alerta.nivelRiesgo.colorFondo,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        alerta.nivelRiesgo.etiqueta,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: alerta.nivelRiesgo.color,
                        ),
                      ),
                    ),
                    if (esHistorial)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('leida'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColores.naranjaBoton,
                        ),
                        icon: const Icon(Icons.mark_email_read, size: 14),
                        label: Text(
                          context.tr('marcar_como_leida'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _alertasService.marcando
                            ? null
                            : () => _marcarComoLeida(alerta),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonToggle(String texto, int index, Color colorTextoSecundario) {
    final bool activo = _opcionSeleccionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _opcionSeleccionada = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: activo ? AppColores.marronOscuro : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                color: activo ? Colors.white : colorTextoSecundario,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
