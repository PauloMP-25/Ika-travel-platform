import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../widgets/dialogo_configuracion_alertas.dart';
import 'pantalla_favoritos.dart';
import 'pantalla_alertas.dart';
import 'pantalla_planer.dart';
import 'pantalla_seguimiento_destino.dart';
import 'pantalla_sos.dart';

class PantallaMas extends StatelessWidget {
  const PantallaMas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILA CON FLECHA DE ATRÁS Y TÍTULO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColores.marronOscuro,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Más Opciones',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Lista de opciones
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Acceso a Planificador de Viajes
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A3B32), Color(0xFF6D5547)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A3B32).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.route, color: Colors.white, size: 28),
                      title: const Text(
                        'Planificador de Viajes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: const Text(
                        'Rutas personalizadas con tiempo y distancia',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PantallaPlaner(),
                          ),
                        );
                      },
                    ),
                  ),
                  // Acceso a SOS
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.shield, color: Colors.white, size: 28),
                      title: const Text(
                        'Asistencia y Emergencia SOS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: const Text(
                        'Alertas con ubicación y contactos de confianza',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PantallaSos(),
                          ),
                        );
                      },
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.favorite_border,
                    titulo: 'Mis Favoritos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaFavoritos(),
                        ),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.notifications_none,
                    titulo: 'Mis Alertas Inteligentes',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaAlertas(),
                        ),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.timeline,
                    titulo: 'Seguimiento de Destinos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PantallaSeguimientoDestino(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _itemMenu(
                    context,
                    icono: Icons.menu_book,
                    titulo: 'Guía de actividades',
                    onTap: () {},
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.info_outline,
                    titulo: 'Mejor hora para visitar',
                    onTap: () {},
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.help_outline,
                    titulo: 'Consejos para el turista',
                    onTap: () {},
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.info_outline,
                    titulo: 'Sobre la app Ika Travel',
                    onTap: () {},
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.settings_outlined,
                    titulo: 'Configuración de alertas',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) =>
                            const DialogoConfiguracionAlertas(),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.share_outlined,
                    titulo: 'Compartir app',
                    onTap: () {},
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.contact_support_outlined,
                    titulo: 'Contacto o ayuda',
                    onTap: () {},
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemMenu(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icono, color: AppColores.marronOscuro),
        title: Text(
          titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColores.marronOscuro,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColores.grisTexto,
        ),
        onTap: onTap,
      ),
    );
  }
}
