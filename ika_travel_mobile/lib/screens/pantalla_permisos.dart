import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/tema.dart';
import '../services/persistencia_service.dart';

/// Pantalla de permisos que se muestra ANTES de entrar a la app.
///
/// Explica, en lenguaje claro, cada permiso que necesita Ika Travel y para
/// qué se usa. El permiso de **ubicación es obligatorio** (clima, mapa y las
/// coordenadas de la alerta SOS dependen de él); los demás son opcionales pero
/// recomendados. Solo cuando la ubicación está concedida se habilita el botón
/// "Continuar".
class PantallaPermisos extends StatefulWidget {
  final VoidCallback onCompletado;

  const PantallaPermisos({super.key, required this.onCompletado});

  @override
  State<PantallaPermisos> createState() => _PantallaPermisosState();
}

class _ItemPermiso {
  final Permission permission;
  final IconData icono;
  final Color color;
  final String titulo;
  final String descripcion;
  final bool obligatorio;

  const _ItemPermiso({
    required this.permission,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.descripcion,
    this.obligatorio = false,
  });
}

class _PantallaPermisosState extends State<PantallaPermisos> {
  static const String _claveVisto = 'permisos_onboarding_visto';
  final PersistenciaService _persistencia = PersistenciaService();

  final List<_ItemPermiso> _items = const [
    _ItemPermiso(
      permission: Permission.location,
      icono: Icons.location_on_rounded,
      color: AppColores.turquesaOasis,
      titulo: 'Ubicación (obligatorio)',
      descripcion:
          'Indispensable para mostrarte el clima de tu zona, ubicarte en el '
          'mapa y enviar tus coordenadas exactas en una alerta SOS.',
      obligatorio: true,
    ),
    _ItemPermiso(
      permission: Permission.sms,
      icono: Icons.sms_rounded,
      color: AppColores.naranjaBoton,
      titulo: 'Enviar SMS',
      descripcion:
          'Permite que la alerta SOS envíe automáticamente un mensaje con tu '
          'ubicación a tus contactos de confianza, sin abrir otra app.',
    ),
    _ItemPermiso(
      permission: Permission.phone,
      icono: Icons.call_rounded,
      color: AppColores.rojoAlerta,
      titulo: 'Llamadas de emergencia',
      descripcion:
          'Permite llamar directamente a tu contacto principal cuando actives '
          'una alerta de emergencia.',
    ),
    _ItemPermiso(
      permission: Permission.microphone,
      icono: Icons.mic_rounded,
      color: AppColores.verdeOasis,
      titulo: 'Micrófono',
      descripcion:
          'Necesario para el traductor por voz: habla y la app traduce lo que '
          'dices al idioma que elijas.',
    ),
  ];

  final Map<Permission, PermissionStatus> _estados = {};
  bool _cargando = true;
  bool _procesando = false;

  bool get _ubicacionConcedida =>
      _estados[Permission.location]?.isGranted ?? false;

  @override
  void initState() {
    super.initState();
    _evaluarArranque();
  }

  Future<void> _evaluarArranque() async {
    // Si ya pasó por aquí antes y la ubicación sigue concedida, no lo molestamos.
    final visto = await _persistencia.leerJson(_claveVisto);
    for (final item in _items) {
      _estados[item.permission] = await item.permission.status;
    }
    if (visto != null && _ubicacionConcedida) {
      widget.onCompletado();
      return;
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _refrescarEstados() async {
    for (final item in _items) {
      _estados[item.permission] = await item.permission.status;
    }
    if (mounted) setState(() {});
  }

  Future<void> _solicitar(_ItemPermiso item) async {
    final estado = _estados[item.permission];
    if (estado != null && estado.isPermanentlyDenied) {
      // Ya no se puede pedir por diálogo: abrir ajustes del sistema.
      await openAppSettings();
      await _refrescarEstados();
      return;
    }
    final nuevo = await item.permission.request();
    _estados[item.permission] = nuevo;
    if (mounted) setState(() {});
  }

  Future<void> _permitirTodos() async {
    setState(() => _procesando = true);
    for (final item in _items) {
      final estado = _estados[item.permission];
      if (estado != null && estado.isGranted) continue;
      if (estado != null && estado.isPermanentlyDenied) continue;
      _estados[item.permission] = await item.permission.request();
    }
    if (mounted) setState(() => _procesando = false);
  }

  Future<void> _continuar() async {
    await _persistencia.guardarJson(_claveVisto, {'visto': true});
    widget.onCompletado();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: AppColores.arenaFondo,
        body: Center(
          child: CircularProgressIndicator(color: AppColores.naranjaBoton),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColores.naranjaBoton,
                            AppColores.turquesaOasis,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_user_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Permisos de Ika Travel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Antes de empezar, autoriza lo que la app '
                                  'necesita para cuidarte durante tu viaje.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final item in _items) _tarjetaPermiso(item),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 15, color: AppColores.grisTexto),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tu información solo se usa dentro de la app. '
                            'Puedes cambiar estos permisos cuando quieras desde '
                            'los ajustes del teléfono.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColores.grisTexto,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _barraInferior(),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPermiso(_ItemPermiso item) {
    final estado = _estados[item.permission];
    final concedido = estado?.isGranted ?? false;
    final permanente = estado?.isPermanentlyDenied ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: concedido
              ? AppColores.verdeOasis.withValues(alpha: 0.5)
              : (item.obligatorio
                  ? AppColores.naranjaBoton.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icono, color: item.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColores.marronOscuro,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.descripcion,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.grisTexto,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                _accionPermiso(item, concedido, permanente),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionPermiso(_ItemPermiso item, bool concedido, bool permanente) {
    if (concedido) {
      return Row(
        children: const [
          Icon(Icons.check_circle_rounded,
              size: 18, color: AppColores.verdeOasis),
          SizedBox(width: 6),
          Text(
            'Permitido',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColores.verdeOasis,
            ),
          ),
        ],
      );
    }

    final etiqueta = permanente ? 'Abrir ajustes' : 'Permitir';
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _solicitar(item),
        style: OutlinedButton.styleFrom(
          foregroundColor: item.color,
          side: BorderSide(color: item.color.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(permanente ? Icons.settings : Icons.add, size: 16),
        label: Text(
          etiqueta,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _barraInferior() {
    final puedeContinuar = _ubicacionConcedida && !_procesando;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_ubicacionConcedida)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColores.naranjaBoton),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'La ubicación es obligatoria para usar Ika Travel.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColores.naranjaBoton,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _procesando ? null : _permitirTodos,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColores.turquesaOasis,
                side: const BorderSide(color: AppColores.turquesaOasis),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _procesando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColores.turquesaOasis),
                    )
                  : const Text(
                      'Permitir todos',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: puedeContinuar ? _continuar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaBoton,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColores.naranjaBoton.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
