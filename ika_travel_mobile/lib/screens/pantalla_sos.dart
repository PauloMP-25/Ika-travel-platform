import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/navegacion_service.dart';
import '../config/tema.dart';
import '../services/sos_service.dart';

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

  void _ejecutarAccionSos({required bool esPrueba}) {
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

    final mensaje = _sosService.generarMensajeEmergencia(modoPrueba: esPrueba);

    // Copiar al portapapeles como respaldo seguro
    Clipboard.setData(ClipboardData(text: mensaje));

    // Mostrar modal con el texto preparado y advertencia de confirmación manual
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: esPrueba ? Colors.amber.withValues(alpha: 0.2) : const Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      esPrueba ? Icons.science_outlined : Icons.outgoing_mail,
                      color: esPrueba ? Colors.amber.shade900 : const Color(0xFFE53935),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esPrueba ? 'Simulación SOS (Modo Prueba)' : 'Mensaje de Emergencia Preparado',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColores.marronOscuro,
                          ),
                        ),
                        Text(
                          esPrueba
                              ? 'Prueba sin despacho real'
                              : 'Destinatario: ${contacto.nombre} (${contacto.telefono})',
                          style: const TextStyle(fontSize: 13, color: AppColores.grisTexto),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColores.arenaFondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0D7CC)),
                ),
                child: Text(
                  mensaje,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: AppColores.marronOscuro),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Importante: El mensaje ha sido copiado al portapapeles. Al abrir la app de mensajería debes pulsar "Enviar" para confirmar el despacho real.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6D4C41)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColores.naranjaBoton),
                      ),
                      icon: const Icon(Icons.copy, color: AppColores.naranjaBoton),
                      label: const Text(
                        'Copiar Texto',
                        style: TextStyle(color: AppColores.naranjaBoton),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: mensaje));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📋 Mensaje copiado al portapapeles.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: esPrueba ? Colors.blueGrey : const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.send),
                      label: Text(esPrueba ? 'Cerrar Prueba' : 'Abrir Mensajes'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (!esPrueba) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColores.marronOscuro,
                              content: Text(
                                '📲 Abriendo canal para ${contacto.nombre}. Recuerda pulsar "Enviar" en tu aplicación de mensajes.',
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.blueGrey,
                              content: Text('🧪 Simulación completada sin enviar mensajes reales.'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                            icon: const Icon(Icons.warning, color: Color(0xFFD32F2F), size: 24),
                            label: const Text(
                              'ACTIVAR SOS DE EMERGENCIA',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: () => _ejecutarAccionSos(esPrueba: false),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          icon: const Icon(Icons.science_outlined, size: 18),
                          label: const Text(
                            'Modo Prueba (Simular sin enviar)',
                            style: TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                          ),
                          onPressed: () => _ejecutarAccionSos(esPrueba: true),
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
                  Row(
                    children: [
                      Icon(
                        existe ? Icons.verified_user : Icons.warning_amber_rounded,
                        color: existe ? Colors.green : Colors.orange,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Contacto de Confianza',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColores.naranjaBoton,
                      padding: EdgeInsets.zero,
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
                const Text(
                  '⚠️ No tienes un contacto registrado. Configúralo para poder generar y enviar alertas de emergencia personalizadas.',
                  style: TextStyle(fontSize: 13, color: Color(0xFFE65100)),
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
                  const Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: AppColores.marronOscuro, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Ubicación en el Mensaje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ],
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
              const Row(
                children: [
                  Icon(Icons.preview_outlined, color: AppColores.marronOscuro, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Vista Previa del Texto SOS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
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
          const Row(
            children: [
              Icon(Icons.local_phone_outlined, color: AppColores.marronOscuro, size: 22),
              SizedBox(width: 8),
              Text(
                'Centrales de Emergencia Oficiales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColores.marronOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._sosService.numerosOficiales.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColores.arenaFondo.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.numero,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nombre,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColores.marronOscuro,
                          ),
                        ),
                        Text(
                          item.descripcion,
                          style: const TextStyle(fontSize: 11, color: AppColores.grisTexto),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
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
        title: const Row(
          children: [
            Icon(Icons.info, color: AppColores.naranjaBoton),
            SizedBox(width: 8),
            Text('Compatibilidad y Envíos', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🌐 Ejecución en Navegador Web (Chrome):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Por políticas de seguridad y privacidad (Sandboxing web), los navegadores web no pueden despachar SMS ni llamadas de fondo sin interacción del usuario. Por ello, la app prepara el texto exacto, lo copia al portapapeles y facilita los enlaces para confirmación manual.',
                style: TextStyle(fontSize: 12, color: AppColores.marronOscuro),
              ),
              SizedBox(height: 12),
              Text(
                '📱 Despliegue en Android Nativo:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Para enviar SMS de fondo en Android se requiere el permiso SEND_SMS en AndroidManifest.xml. Google Play clasifica este permiso como de alto riesgo y exige justificación estricta. El enfoque recomendado y seguro consiste en lanzar la aplicación SMS del sistema (Intent ACTION_SENDTO) precargando el destinatario y mensaje para que el usuario confirme con un solo toque.',
                style: TextStyle(fontSize: 12, color: AppColores.marronOscuro),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: AppColores.naranjaBoton)),
          ),
        ],
      ),
    );
  }
}
