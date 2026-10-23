import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/tema.dart';
import '../services/sos_service.dart';

class ModalCuentaRegresivaSos extends StatefulWidget {
  final ContactoEmergencia contacto;
  final String mensaje;
  final bool esModoChoque;
  final VoidCallback onCancelado;
  final VoidCallback onDespachado;

  const ModalCuentaRegresivaSos({
    super.key,
    required this.contacto,
    required this.mensaje,
    this.esModoChoque = false,
    required this.onCancelado,
    required this.onDespachado,
  });

  static Future<void> mostrar({
    required BuildContext context,
    required ContactoEmergencia contacto,
    required String mensaje,
    bool esModoChoque = false,
    VoidCallback? onCancelado,
    VoidCallback? onDespachado,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => ModalCuentaRegresivaSos(
        contacto: contacto,
        mensaje: mensaje,
        esModoChoque: esModoChoque,
        onCancelado: onCancelado ?? () {},
        onDespachado: onDespachado ?? () {},
      ),
    );
  }

  @override
  State<ModalCuentaRegresivaSos> createState() => _ModalCuentaRegresivaSosState();
}

class _ModalCuentaRegresivaSosState extends State<ModalCuentaRegresivaSos>
    with SingleTickerProviderStateMixin {
  final SosService _sosService = SosService();
  int _segundosRestantes = 10;
  Timer? _timer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Feedback táctil inmediato
    HapticFeedback.heavyImpact();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (_segundosRestantes > 1) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        _timer?.cancel();
        _ejecutarDespachoAutomatico();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarDespachoAutomatico() async {
    Navigator.of(context).pop();
    widget.onDespachado();

    // 1. Envío silencioso nativo de SMS por red celular
    await _sosService.enviarSmsSilenciosoDirecto(
      telefono: widget.contacto.telefono,
      mensaje: widget.mensaje,
    );

    // 2. Iniciar llamada telefónica directa de auxilio
    await Future.delayed(const Duration(milliseconds: 600));
    await _sosService.realizarLlamadaDirectaAuxilio(
      telefono: widget.contacto.telefono,
    );
  }

  void _cancelar() {
    _timer?.cancel();
    Navigator.of(context).pop();
    widget.onCancelado();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono animado de impacto o SOS
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_animController.value * 0.12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD32F2F),
                        width: 2.5,
                      ),
                    ),
                    child: Icon(
                      widget.esModoChoque
                          ? Icons.car_crash_rounded
                          : Icons.emergency_share_rounded,
                      color: const Color(0xFFD32F2F),
                      size: 42,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            Text(
              widget.esModoChoque
                  ? '¿ESTÁS BIEN?\nPosible impacto o frenado brusco'
                  : 'DESPACHO DE EMERGENCIA AUTOMÁTICO',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFFB71C1C),
                letterSpacing: 0.3,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Si no cancelas, la app enviará un SMS silencioso con tus coordenadas exactas y llamará a:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColores.grisTexto,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.contacto.nombre} (${widget.contacto.telefono})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColores.marronOscuro,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Reloj circular de cuenta regresiva
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: _segundosRestantes / 10.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFD32F2F),
                    ),
                  ),
                ),
                Text(
                  '$_segundosRestantes',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // BOTÓN PRINCIPAL: ESTOY BIEN / CANCELAR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 22),
                label: const Text(
                  'ESTOY BIEN (CANCELAR ALERTA)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _cancelar,
              ),
            ),

            const SizedBox(height: 10),

            // BOTÓN SECUNDARIO: ENVIAR YA SIN ESPERAR
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                ),
                icon: const Icon(Icons.flash_on, size: 18),
                label: const Text(
                  'Enviar auxilio ahora mismo sin esperar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
                onPressed: () {
                  _timer?.cancel();
                  _ejecutarDespachoAutomatico();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
