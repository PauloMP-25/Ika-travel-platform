import 'package:flutter/material.dart';
import '../config/tema.dart';

class PantallaConfigurarAlertas extends StatefulWidget {
  const PantallaConfigurarAlertas({super.key});

  @override
  State<PantallaConfigurarAlertas> createState() => _PantallaConfigurarAlertasState();
}

class _PantallaConfigurarAlertasState extends State<PantallaConfigurarAlertas> {
  // Estado de los tipos de alerta
  bool _cambiosClimaticos = true;
  bool _cambiosRutas = true;
  bool _estadoDestinos = true;
  bool _lugaresFavoritos = true;
  bool _mejorHoraVisitar = true;

  // Estado de los canales de notificación
  bool _notificacionesApp = true;
  bool _correoElectronico = false;
  bool _sms = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColores.marronOscuro,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Configurar alertas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  const SizedBox(width: 48), // Espacio para equilibrar
                ],
              ),
            ),

            // Descripción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Recibe notificaciones automáticas cuando haya cambios en tus destinos y actividades favoritas.',
                style: TextStyle(
                  color: AppColores.grisTexto,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Contenido scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección: Tipos de alerta
                    _buildSectionTitle('Tipos de alerta'),
                    const SizedBox(height: 8),
                    _buildAlertTypeCard(),

                    const SizedBox(height: 24),

                    // Sección: Canales de notificación
                    _buildSectionTitle('Canales de notificación'),
                    const SizedBox(height: 8),
                    _buildNotificationChannelsCard(),

                    const SizedBox(height: 32),

                    // Botón guardar
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColores.marronOscuro,
      ),
    );
  }

  Widget _buildAlertTypeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAlertTypeRow(
            icon: Icons.wb_sunny_rounded,
            iconColor: AppColores.naranjaBoton,
            title: 'Cambios climáticos',
            subtitle: 'Avisos por variaciones de temperatura, viento, lluvia, etc.',
            value: _cambiosClimaticos,
            onChanged: (val) => setState(() => _cambiosClimaticos = val),
          ),
          _buildDivider(),
          _buildAlertTypeRow(
            icon: Icons.alt_route_rounded,
            iconColor: AppColores.marronOscuro,
            title: 'Cambios en rutas',
            subtitle: 'Avisos por cierres o reaperturas de accesos.',
            value: _cambiosRutas,
            onChanged: (val) => setState(() => _cambiosRutas = val),
          ),
          _buildDivider(),
          _buildAlertTypeRow(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColores.marronOscuro,
            title: 'Estado de destinos',
            subtitle: 'Avisos por condiciones de seguridad o capacidad.',
            value: _estadoDestinos,
            onChanged: (val) => setState(() => _estadoDestinos = val),
          ),
          _buildDivider(),
          _buildAlertTypeRow(
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            title: 'Mis lugares favoritos',
            subtitle: 'Notificaciones para lugares guardados.',
            value: _lugaresFavoritos,
            onChanged: (val) => setState(() => _lugaresFavoritos = val),
          ),
          _buildDivider(),
          _buildAlertTypeRow(
            icon: Icons.access_time_rounded,
            iconColor: AppColores.marronOscuro,
            title: 'Mejor hora para visitar',
            subtitle: 'Avisos con la hora ideal según el clima.',
            value: _mejorHoraVisitar,
            onChanged: (val) => setState(() => _mejorHoraVisitar = val),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTypeRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColores.marronOscuro,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColores.grisTexto,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          _buildCustomSwitch(value, onChanged),
        ],
      ),
    );
  }

  Widget _buildNotificationChannelsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildChannelRow(
            icon: Icons.notifications_none_rounded,
            iconColor: AppColores.naranjaBoton,
            title: 'Notificaciones de la app',
            value: _notificacionesApp,
            onChanged: (val) => setState(() => _notificacionesApp = val),
          ),
          _buildDivider(),
          _buildChannelRow(
            icon: Icons.email_rounded,
            iconColor: AppColores.marronOscuro,
            title: 'Correo electrónico',
            value: _correoElectronico,
            onChanged: (val) => setState(() => _correoElectronico = val),
          ),
          _buildDivider(),
          _buildChannelRow(
            icon: Icons.sms_rounded,
            iconColor: AppColores.marronOscuro,
            title: 'Mensaje de texto (SMS)',
            value: _sms,
            onChanged: (val) => setState(() => _sms = val),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColores.marronOscuro,
              ),
            ),
          ),
          _buildCustomSwitch(value, onChanged),
        ],
      ),
    );
  }

  Widget _buildCustomSwitch(bool value, ValueChanged<bool> onChanged) {
    return Transform.scale(
      scale: 0.85,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: AppColores.naranjaBoton,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: Colors.grey.shade300,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFE8E8E8),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.naranjaBoton,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColores.naranjaBoton.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _guardarConfiguracion,
        child: const Text(
          'Guardar configuración',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _guardarConfiguracion() {
    // Aquí se guardaría la configuración (SharedPreferences, backend, etc.)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Configuración guardada correctamente'),
        backgroundColor: AppColores.marronOscuro,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }
}