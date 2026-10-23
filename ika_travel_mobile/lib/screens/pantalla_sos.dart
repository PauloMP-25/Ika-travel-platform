import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/navegacion_service.dart';
import '../config/tema.dart';
import '../services/sos_service.dart';
import '../widgets/modal_cuenta_regresiva_sos.dart';

class PantallaSos extends StatefulWidget {
  final bool mostrarBotonAtras;

  const PantallaSos({
    super.key,
    this.mostrarBotonAtras = true,
  });

  @override
  State<PantallaSos> createState() => _PantallaSosState();
}

class _PantallaSosState extends State<PantallaSos> {
  final SosService _sosService = SosService();
  bool _detectorChoqueActivo = true;

  Future<void> _iniciarCuentaRegresivaSos({bool esModoChoque = false}) async {
    final contacto = _sosService.contactoNotifier.value;
    if (contacto == null) {
      _ejecutarAccionSos(esPrueba: false);
      return;
    }

    if (_sosService.permisoUbicacionConcedido.value) {
      await _sosService.actualizarUbicacionReal();
      if (mounted) setState(() {});
    }

    final mensaje = _sosService.generarMensajeEmergencia(modoPrueba: false);
    Clipboard.setData(ClipboardData(text: mensaje));

    if (!mounted) return;

    ModalCuentaRegresivaSos.mostrar(
      context: context,
      contacto: contacto,
      mensaje: mensaje,
      esModoChoque: esModoChoque,
      onCancelado: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta cancelada. No se enviaron mensajes.')),
        );
      },
      onDespachado: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD32F2F),
            content: Text('🚨 Alerta SOS enviada por SMS silencioso con ubicación GPS.'),
          ),
        );
      },
    );
  }

  void _abrirDialogoContacto(BuildContext context, [ContactoEmergencia? contactoActual]) {
    final nombreCtrl = TextEditingController(text: contactoActual?.nombre ?? '');
    final telCtrl = TextEditingController(text: contactoActual?.telefono ?? '');
    final relCtrl = TextEditingController(text: contactoActual?.relacion ?? 'Familiar');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1, color: Color(0xFFE53935)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  contactoActual == null ? 'Registrar Contacto' : 'Editar Contacto',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColores.marronOscuro,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Este contacto recibirá tu alerta y ubicación en caso de emergencia durante tu viaje por Ica.',
                    style: TextStyle(fontSize: 13, color: AppColores.grisTexto),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre y apellido',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa el nombre del contacto' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Número telefónico',
                      hintText: '+51 987654321',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa un número de teléfono';
                      }
                      if (v.trim().length < 6) {
                        return 'Número telefónico inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: relCtrl,
                    decoration: InputDecoration(
                      labelText: 'Parentesco o relación',
                      hintText: 'Ej. Madre, Amigo/a, Pareja',
                      prefixIcon: const Icon(Icons.people_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColores.grisTexto)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  _sosService.guardarContacto(
                    nombre: nombreCtrl.text,
                    telefono: telCtrl.text,
                    relacion: relCtrl.text,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Contacto de emergencia guardado correctamente.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ejecutarAccionSos({required bool esPrueba}) async {
    final contacto = _sosService.contactoNotifier.value;
    if (contacto == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Sin contacto registrado'),
            ],
          ),
          content: const Text(
            'Antes de preparar la alerta SOS, registra un contacto de confianza (familiar o amigo) que pueda asistirte.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              onPressed: () {
                Navigator.pop(ctx);
                _abrirDialogoContacto(context);
              },
              child: const Text('Registrar contacto ahora', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // Obtener ubicación GPS real satelital si el permiso está activo
    if (_sosService.permisoUbicacionConcedido.value) {
      await _sosService.actualizarUbicacionReal();
      if (mounted) setState(() {});
    }

    final mensaje = _sosService.generarMensajeEmergencia(modoPrueba: esPrueba);

    // Copiar al portapapeles como respaldo
    Clipboard.setData(ClipboardData(text: mensaje));

    if (!mounted) return;

    // Mostrar modal interactivo con acciones en 1 solo toque
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: esPrueba ? Colors.amber.withValues(alpha: 0.2) : const Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      esPrueba ? Icons.science_outlined : Icons.shield_outlined,
                      color: esPrueba ? Colors.amber.shade900 : const Color(0xFFD32F2F),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esPrueba ? 'Simulación SOS (Modo Prueba)' : 'Enviar Alerta SOS en 1 Clic',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColores.marronOscuro,
                          ),
                        ),
                        Text(
                          esPrueba
                              ? 'Prueba sin despacho real'
                              : 'Contacto: ${contacto.nombre} (${contacto.telefono})',
                          style: const TextStyle(fontSize: 12, color: AppColores.grisTexto),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Estado de ubicación GPS real capturada (Reemplaza el texto largo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed, color: Color(0xFF2E7D32), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coordenadas GPS y Enlace de Mapa Listos',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          Text(
                            _sosService.permisoUbicacionConcedido.value
                                ? 'Ubicación satelital en vivo lista para despacho inmediato'
                                : 'Aviso: Ubicación satelital no concedida',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (!esPrueba) ...[
                // BOTÓN 1 PRINCIPAL: DISPARO AUTOMÁTICO (WhatsApp + SMS)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.flash_on, size: 24, color: Colors.yellowAccent),
                    label: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🚨 DISPARO AUTOMÁTICO (WhatsApp + SMS)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Envía por las 2 vías en secuencia de 1 solo toque',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: mensaje));
                      await _sosService.enviarAlertaAutomatica(
                        telefono: contacto.telefono,
                        mensaje: mensaje,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // VÍAS INDIVIDUALES EN PARALELO
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _sosService.abrirWhatsApp(
                            telefono: contacto.telefono,
                            mensaje: mensaje,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: const Text('SMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _sosService.abrirSms(
                            telefono: contacto.telefono,
                            mensaje: mensaje,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // BOTÓN DE LLAMADA DIRECTA AL CONTACTO
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.phone),
                    label: Text('Llamar a ${contacto.nombre} (${contacto.telefono})'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _sosService.llamarNumero(telefono: contacto.telefono);
                    },
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Entendido (Prueba finalizada)'),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16, color: AppColores.grisTexto),
                  label: const Text('Copiar texto manualmente', style: TextStyle(fontSize: 12, color: AppColores.grisTexto)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: mensaje));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📋 Mensaje copiado al portapapeles.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera superior
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  if (widget.mostrarBotonAtras)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColores.marronOscuro),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          NavegacionService.irAInicio();
                        }
                      },
                    )
                  else
                    const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      'Asistencia y SOS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: AppColores.marronOscuro),
                    onPressed: () => _mostrarModalInfoTecnica(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                children: [
                  // Banner de emergencia activo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield, color: Colors.white, size: 28),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Botón de Emergencia Ika',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Prepara una alerta instantánea con tus coordenadas en Ica para tu contacto de confianza y autoridades.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFD32F2F),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 24),
                            label: const Text(
                              'ACTIVAR SOS DE EMERGENCIA',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: () => _iniciarCuentaRegresivaSos(esModoChoque: false),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.touch_app, size: 16),
                          label: const Text(
                            'Opciones manuales (WhatsApp directo)',
                            style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                          ),
                          onPressed: () => _ejecutarAccionSos(esPrueba: false),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          icon: const Icon(Icons.science_outlined, size: 16),
                          label: const Text(
                            'Modo Prueba (Simular sin enviar)',
                            style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                          ),
                          onPressed: () => _ejecutarAccionSos(esPrueba: true),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // TARJETA DE DETECCIÓN INTELIGENTE DE CHOQUES Y CAÍDAS
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _detectorChoqueActivo
                            ? const Color(0xFFD32F2F).withValues(alpha: 0.3)
                            : Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _detectorChoqueActivo
                                    ? const Color(0xFFFFEBEE)
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.car_crash_rounded,
                                color: _detectorChoqueActivo
                                    ? const Color(0xFFD32F2F)
                                    : Colors.grey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Detección de Choques e Impactos',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColores.marronOscuro,
                                    ),
                                  ),
                                  Text(
                                    _detectorChoqueActivo
                                        ? 'Monitoreo activo para tubulares / auto'
                                        : 'Monitoreo pausado',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _detectorChoqueActivo
                                          ? const Color(0xFF2E7D32)
                                          : AppColores.grisTexto,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _detectorChoqueActivo,
                              activeColor: const Color(0xFFD32F2F),
                              onChanged: (val) {
                                setState(() {
                                  _detectorChoqueActivo = val;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Si el vehículo sufre una desaceleración extrema o impacto en las dunas, se activará una alarma con 10s de espera para despachar auxilio por SMS satelital y llamada sin intervención humana.',
                          style: TextStyle(fontSize: 11, color: AppColores.grisTexto, height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD32F2F),
                              side: const BorderSide(color: Color(0xFFD32F2F)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text(
                              'Simular Choque (Probar flujo automático 10s)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _iniciarCuentaRegresivaSos(esModoChoque: true),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sección Contacto de Confianza
                  _seccionContacto(context),

                  const SizedBox(height: 16),

                  // Sección Permiso de Ubicación
                  _seccionUbicacion(),

                  const SizedBox(height: 16),

                  // Vista previa del mensaje
                  _seccionVistaPreviaMensaje(),

                  const SizedBox(height: 16),

                  // Números Oficiales de Emergencia en Perú / Ica
                  _seccionNumerosOficiales(context),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionContacto(BuildContext context) {
    return ValueListenableBuilder<ContactoEmergencia?>(
      valueListenable: _sosService.contactoNotifier,
      builder: (context, contacto, _) {
        final existe = contacto != null;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: existe ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          existe ? Icons.verified_user : Icons.warning_amber_rounded,
                          color: existe ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Contacto de Confianza',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColores.marronOscuro,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColores.naranjaBoton,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: Icon(existe ? Icons.edit : Icons.add, size: 16),
                    label: Text(existe ? 'Editar' : 'Registrar'),
                    onPressed: () => _abrirDialogoContacto(context, contacto),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (existe) ...[
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColores.arenaFondo,
                      child: const Icon(Icons.person, color: AppColores.marronOscuro),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contacto.nombre,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          Text(
                            '${contacto.telefono} • ${contacto.relacion}',
                            style: const TextStyle(fontSize: 13, color: AppColores.grisTexto),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      tooltip: 'Eliminar contacto',
                      onPressed: () => _sosService.eliminarContacto(),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE65100)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No tienes un contacto registrado. Configúralo para poder generar y enviar alertas de emergencia personalizadas.',
                        style: TextStyle(fontSize: 13, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _seccionUbicacion() {
    return ValueListenableBuilder<bool>(
      valueListenable: _sosService.permisoUbicacionConcedido,
      builder: (context, tienePermiso, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: AppColores.marronOscuro, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Ubicación en el Mensaje',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColores.marronOscuro,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    activeThumbColor: AppColores.naranjaBoton,
                    value: tienePermiso,
                    onChanged: (val) => _sosService.setPermisoUbicacion(val),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (tienePermiso) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ubicación GPS activa: ${_sosService.lugarReferencia} (${_sosService.latitudActual}, ${_sosService.longitudActual})',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Permiso desactivado. La alerta se redactará indicando que la ubicación no está disponible.',
                        style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _seccionVistaPreviaMensaje() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _sosService.contactoNotifier,
        _sosService.permisoUbicacionConcedido,
      ]),
      builder: (context, _) {
        final mensaje = _sosService.generarMensajeEmergencia(modoPrueba: false);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.preview_outlined, color: AppColores.marronOscuro, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Vista Previa del Texto SOS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColores.arenaFondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  mensaje,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColores.marronOscuro),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _seccionNumerosOficiales(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_phone_outlined, color: AppColores.marronOscuro, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Centrales de Emergencia Oficiales',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColores.marronOscuro,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._sosService.numerosOficiales.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColores.arenaFondo.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColores.marronOscuro.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          item.numero,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD32F2F),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.phone_in_talk, size: 20, color: Color(0xFF2E7D32)),
                            tooltip: 'Llamar de inmediato',
                            onPressed: () => _sosService.llamarNumero(telefono: item.numero),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy, size: 18, color: AppColores.marronOscuro),
                            tooltip: 'Copiar número',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item.numero));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Número ${item.numero} copiado al portapapeles.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.nombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.descripcion,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColores.grisTexto,
                      height: 1.25,
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

  void _mostrarModalInfoTecnica(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFFD32F2F)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Guía de Asistencia SOS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.touch_app_rounded, color: AppColores.naranjaBoton, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alertas en 1 clic: Pulsa "Activar SOS" para despachar tu ubicación exacta directamente a WhatsApp o SMS de tu contacto.',
                      style: TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gps_fixed, color: Color(0xFF2E7D32), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ubicación Satelital: Se extraen tus coordenadas reales en Ica y se genera un enlace de Google Maps para que puedan localizarte.',
                      style: TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.phone_in_talk, color: Color(0xFF1976D2), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Llamadas Rápidas: Toca el icono de teléfono junto a la Policía (105), Bomberos (116) o SAMU (106) para llamar de inmediato.',
                      style: TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.marronOscuro,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
