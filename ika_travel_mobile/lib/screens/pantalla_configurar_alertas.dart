import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../config/traducciones_scope.dart';

class PantallaConfigurarAlertas extends StatefulWidget {
  const PantallaConfigurarAlertas({super.key});

  @override
  State<PantallaConfigurarAlertas> createState() =>
      _PantallaConfigurarAlertasState();
}

class _PantallaConfigurarAlertasState extends State<PantallaConfigurarAlertas> {
  bool _cambiosClimaticos = true;
  bool _cambiosRutas = true;
  bool _estadoDestinos = true;
  bool _lugaresFavoritos = true;
  bool _mejorHoraVisitar = true;

  bool _notificacionesApp = true;
  bool _correoElectronico = false;
  bool _sms = false;

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorTexto, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    context.tr('configurar_alertas'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                context.tr('recibe_notificaciones'),
                style: TextStyle(
                  color: colorTextoSecundario,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context.tr('tipos_alerta'), colorTexto),
                    const SizedBox(height: 8),
                    _buildAlertTypeCard(
                      colorTarjeta,
                      colorTexto,
                      colorTextoSecundario,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      context.tr('canales_notificacion'),
                      colorTexto,
                    ),
                    const SizedBox(height: 8),
                    _buildNotificationChannelsCard(
                      colorTarjeta,
                      colorTexto,
                      colorTextoSecundario,
                    ),
                    const SizedBox(height: 32),
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

  Widget _buildSectionTitle(String title, Color colorTexto) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: colorTexto,
      ),
    );
  }

  Widget _buildAlertTypeCard(
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorTarjeta,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            title: context.tr('cambios_climaticos'),
            subtitle: context.tr('aviso_temperatura'),
            value: _cambiosClimaticos,
            onChanged: (val) => setState(() => _cambiosClimaticos = val),
            colorTexto: colorTexto,
            colorTextoSecundario: colorTextoSecundario,
          ),
          _buildDivider(colorTextoSecundario),
          _buildAlertTypeRow(
            icon: Icons.alt_route_rounded,
            iconColor: AppColores.marronOscuro,
            title: context.tr('cambios_rutas'),
            subtitle: context.tr('aviso_cierres'),
            value: _cambiosRutas,
            onChanged: (val) => setState(() => _cambiosRutas = val),
            colorTexto: colorTexto,
            colorTextoSecundario: colorTextoSecundario,
          ),
          _buildDivider(colorTextoSecundario),
          _buildAlertTypeRow(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColores.marronOscuro,
            title: context.tr('estado_destinos'),
            subtitle: context.tr('aviso_seguridad'),
            value: _estadoDestinos,
            onChanged: (val) => setState(() => _estadoDestinos = val),
            colorTexto: colorTexto,
            colorTextoSecundario: colorTextoSecundario,
          ),
          _buildDivider(colorTextoSecundario),
          _buildAlertTypeRow(
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            title: context.tr('mis_lugares_favoritos'),
            subtitle: context.tr('noti_lugares_guardados'),
            value: _lugaresFavoritos,
            onChanged: (val) => setState(() => _lugaresFavoritos = val),
            colorTexto: colorTexto,
            colorTextoSecundario: colorTextoSecundario,
          ),
          _buildDivider(colorTextoSecundario),
          _buildAlertTypeRow(
            icon: Icons.access_time_rounded,
            iconColor: AppColores.marronOscuro,
            title: context.tr('mejor_hora_visitar'),
            subtitle: context.tr('aviso_hora_ideal'),
            value: _mejorHoraVisitar,
            onChanged: (val) => setState(() => _mejorHoraVisitar = val),
            colorTexto: colorTexto,
            colorTextoSecundario: colorTextoSecundario,
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
    required Color colorTexto,
    required Color colorTextoSecundario,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorTextoSecundario,
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

  Widget _buildNotificationChannelsCard(
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorTarjeta,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            title: context.tr('notificaciones_app'),
            value: _notificacionesApp,
            onChanged: (val) => setState(() => _notificacionesApp = val),
            colorTexto: colorTexto,
          ),
          _buildDivider(colorTextoSecundario),
          _buildChannelRow(
            icon: Icons.email_rounded,
            iconColor: AppColores.marronOscuro,
            title: context.tr('correo_electronico'),
            value: _correoElectronico,
            onChanged: (val) => setState(() => _correoElectronico = val),
            colorTexto: colorTexto,
          ),
          _buildDivider(colorTextoSecundario),
          _buildChannelRow(
            icon: Icons.sms_rounded,
            iconColor: AppColores.marronOscuro,
            title: context.tr('mensaje_texto'),
            value: _sms,
            onChanged: (val) => setState(() => _sms = val),
            colorTexto: colorTexto,
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
    required Color colorTexto,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorTexto,
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

  Widget _buildDivider(Color color) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: color.withValues(alpha: 0.2),
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
          shadowColor: AppColores.naranjaBoton.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _guardarConfiguracion,
        child: Text(
          context.tr('guardar_configuracion'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _guardarConfiguracion() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('config_guardada')),
        backgroundColor: AppColores.marronOscuro,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }
}
