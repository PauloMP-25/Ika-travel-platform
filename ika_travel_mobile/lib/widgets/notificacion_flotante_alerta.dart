import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/colores_tema.dart';
import '../config/navegacion_service.dart';
import '../config/tema.dart';
import '../models/alerta_modelo.dart';
import '../screens/pantalla_detalle_alerta.dart';

/// Notificación flotante emergente (estilo WhatsApp / Heads-up) que desciende
/// suavemente desde la parte superior de la pantalla cuando el backend
/// emite o actualiza una alerta climática crítica (ej. Reserva Nacional de Paracas).
///
/// Características:
/// - Al tocarla, vibra y navega directamente a [PantallaDetalleAlerta].
/// - Permite descartar deslizando hacia arriba o tocando la "X".
/// - Se auto-descarta tras 6.5 segundos.
/// - Diseñada con estética premium (bordes redondeados, sombra suave, badge de severidad).
class NotificacionFlotanteAlerta {
  static OverlayEntry? _overlayActual;
  static Timer? _timerAutoCierre;

  static void mostrar({
    required AlertaClima alerta,
    BuildContext? context,
  }) {
    final ctx = context ?? NavegacionService.navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint('[NotificacionFlotanteAlerta] Contexto no disponible para mostrar overlay');
      return;
    }

    final overlayState = Overlay.maybeOf(ctx) ??
        NavegacionService.navigatorKey.currentState?.overlay;

    if (overlayState == null) {
      debugPrint('[NotificacionFlotanteAlerta] OverlayState no encontrado');
      return;
    }

    // Feedback táctil suave para alertar al usuario
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    // Cerrar notificación previa si existía
    cerrar();

    _overlayActual = OverlayEntry(
      builder: (context) => _BannerFlotanteWidget(
        alerta: alerta,
        onCerrar: cerrar,
        onTap: () {
          cerrar();
          final nav = NavegacionService.navigatorKey.currentState;
          if (nav != null) {
            nav.push(
              MaterialPageRoute(
                builder: (_) => PantallaDetalleAlerta(alerta: alerta),
              ),
            );
          }
        },
      ),
    );

    overlayState.insert(_overlayActual!);

    _timerAutoCierre?.cancel();
    _timerAutoCierre = Timer(const Duration(milliseconds: 6500), () {
      cerrar();
    });
  }

  static void cerrar() {
    _timerAutoCierre?.cancel();
    _timerAutoCierre = null;
    if (_overlayActual != null) {
      _overlayActual?.remove();
      _overlayActual = null;
    }
  }
}

class _BannerFlotanteWidget extends StatefulWidget {
  final AlertaClima alerta;
  final VoidCallback onCerrar;
  final VoidCallback onTap;

  const _BannerFlotanteWidget({
    required this.alerta,
    required this.onCerrar,
    required this.onTap,
  });

  @override
  State<_BannerFlotanteWidget> createState() => _BannerFlotanteWidgetState();
}

class _BannerFlotanteWidgetState extends State<_BannerFlotanteWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _descartarAnimado() async {
    await _animCtrl.reverse();
    widget.onCerrar();
  }

  Color _obtenerColorSeveridad(NivelRiesgo nivel) {
    switch (nivel) {
      case NivelRiesgo.critico:
        return const Color(0xFFE53935);
      case NivelRiesgo.alto:
        return const Color(0xFFFF9800);
      case NivelRiesgo.precaucion:
        return const Color(0xFFFFB300);
      case NivelRiesgo.informativo:
        return const Color(0xFF1E88E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorRiesgo = _obtenerColorSeveridad(widget.alerta.nivelRiesgo);

    final bgCard = isDark ? const Color(0xFF1E232A) : Colors.white;
    final borderCard = isDark ? Colors.white12 : Colors.black.withOpacity(0.06);
    final textoPrincipal = isDark ? Colors.white : const Color(0xFF1F2937);
    final textoSecundario = isDark ? Colors.white70 : const Color(0xFF4B5563);

    return Positioned(
      top: media.padding.top + 8,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onCerrar(),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCard),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.45 : 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Indicador vertical de severidad
                      Container(
                        width: 4,
                        height: 54,
                        margin: const EdgeInsets.only(right: 10, top: 2),
                        decoration: BoxDecoration(
                          color: colorRiesgo,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),

                      // Icono con insignia
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorRiesgo.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: colorRiesgo,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Textos informativos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Cabecera: App + Destino + Hora
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'IKA TRAVEL • ALERTA ${widget.alerta.destino.toUpperCase()}',
                                    style: TextStyle(
                                      color: colorRiesgo,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'AHORA',
                                    style: TextStyle(
                                      color: textoSecundario,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),

                            // Título de la alerta
                            Text(
                              widget.alerta.titulo,
                              style: TextStyle(
                                color: textoPrincipal,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),

                            // Mensaje / Motivo
                            Text(
                              widget.alerta.motivoCambio.isNotEmpty
                                  ? widget.alerta.motivoCambio
                                  : 'Condiciones meteorológicas de riesgo detectadas.',
                              style: TextStyle(
                                color: textoSecundario,
                                fontSize: 12,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),

                            // CTA Tocar para ver
                            Row(
                              children: [
                                Text(
                                  'Toca para ver recomendaciones y medidas',
                                  style: TextStyle(
                                    color: AppColores.naranjaBoton,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 10,
                                  color: AppColores.naranjaBoton,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Botón cerrar (X)
                      InkWell(
                        onTap: _descartarAnimado,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: textoSecundario.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
