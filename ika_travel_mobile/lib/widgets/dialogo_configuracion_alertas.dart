import 'package:flutter/material.dart';
import '../config/tema.dart';
import '../services/alertas_service.dart';

/// Diálogo modal para gestión de permisos y configuración de alertas inteligentes (Req 11)
class DialogoConfiguracionAlertas extends StatefulWidget {
  const DialogoConfiguracionAlertas({super.key});

  @override
  State<DialogoConfiguracionAlertas> createState() =>
      _DialogoConfiguracionAlertasState();
}

class _DialogoConfiguracionAlertasState
    extends State<DialogoConfiguracionAlertas> {
  final AlertasService _alertasService = AlertasService();

  late bool _permisosConcedidos;
  late bool _pushHabilitado;
  late bool _alertarViento;
  late bool _alertarOleaje;
  late bool _alertarUv;
  late bool _alertarLluvia;
  late String _frecuencia;

  @override
  void initState() {
    super.initState();
    final config = _alertasService.configNotifier.value;
    _permisosConcedidos = config.permisosConcedidos;
    _pushHabilitado = config.pushHabilitado;
    _alertarViento = config.alertarViento;
    _alertarOleaje = config.alertarOleaje;
    _alertarUv = config.alertarUv;
    _alertarLluvia = config.alertarLluvia;
    _frecuencia = config.frecuenciaRevision;
  }

  void _guardarConfiguracion() {
    final nueva = ConfiguracionNotificaciones(
      permisosConcedidos: _permisosConcedidos,
      pushHabilitado: _pushHabilitado,
      alertarViento: _alertarViento,
      alertarOleaje: _alertarOleaje,
      alertarUv: _alertarUv,
      alertarLluvia: _alertarLluvia,
      frecuenciaRevision: _frecuencia,
    );
    _alertasService.actualizarConfiguracion(nueva);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuración de alertas guardada exitosamente.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título y botón cerrar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Configuración de Alertas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColores.grisTexto),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Personaliza los umbrales climáticos y canales de notificación para tus destinos seguidos.',
                style: TextStyle(fontSize: 12, color: AppColores.grisTexto),
              ),

              const SizedBox(height: 14),

              // Sección 1: Permisos del Sistema
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColores.arenaFondo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _permisosConcedidos
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: _permisosConcedidos
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Permiso de notificaciones',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          Text(
                            _permisosConcedidos ? 'Concedido' : 'Denegado / Requerido',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _permisosConcedidos
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _permisosConcedidos,
                      activeTrackColor: AppColores.naranjaBoton,
                      onChanged: (val) {
                        setState(() => _permisosConcedidos = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Nota técnica transparente sobre Push Notifications (Req 11)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Arquitectura Push: En este frontend se gestiona el estado y preferencias. Para notificaciones reales con la app en segundo plano o cerrada se requiere vincular Firebase Cloud Messaging (FCM) y cron en backend.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF5D4037),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Sección 2: Tipos de cambios a alertar
              const Text(
                'Tipos de eventos a notificar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColores.marronOscuro,
                ),
              ),
              const SizedBox(height: 6),

              _buildSwitchTile(
                titulo: 'Vientos fuertes y ráfagas',
                descripcion: 'Alertar ante vientos > 25 km/h (Sandboarding y Dunas)',
                icono: Icons.air,
                valor: _alertarViento,
                onChanged: (v) => setState(() => _alertarViento = v),
              ),
              _buildSwitchTile(
                titulo: 'Oleaje anómalo y estado de puerto',
                descripcion: 'Alertar ante olas > 1.8 m (Islas Ballestas y Náutica)',
                icono: Icons.waves,
                valor: _alertarOleaje,
                onChanged: (v) => setState(() => _alertarOleaje = v),
              ),
              _buildSwitchTile(
                titulo: 'Radiación solar extrema',
                descripcion: 'Alertar ante índice UV >= 8 (Reserva de Paracas)',
                icono: Icons.wb_sunny_outlined,
                valor: _alertarUv,
                onChanged: (v) => setState(() => _alertarUv = v),
              ),
              _buildSwitchTile(
                titulo: 'Lluvias y tormentas inusuales',
                descripcion: 'Alertar ante precipitaciones atípicas en el valle',
                icono: Icons.water_drop_outlined,
                valor: _alertarLluvia,
                onChanged: (v) => setState(() => _alertarLluvia = v),
              ),

              const SizedBox(height: 14),

              // Botón de guardar
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.marronOscuro,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _guardarConfiguracion,
                  child: const Text('Guardar Preferencias'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String titulo,
    required String descripcion,
    required IconData icono,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 20, color: AppColores.naranjaBoton),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColores.marronOscuro,
                  ),
                ),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 10.5, color: AppColores.grisTexto),
                ),
              ],
            ),
          ),
          Switch(
            value: valor,
            activeTrackColor: AppColores.naranjaBoton,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
