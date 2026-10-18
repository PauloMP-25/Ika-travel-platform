import 'pantalla_traduccion.dart';
import 'package:flutter/material.dart';

import '../config/tema.dart';
import 'pantalla_favoritos.dart';
import 'pantalla_alertas.dart';

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
            // 👇 FILA CON FLECHA DE ATRÁS Y TÍTULO
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
                      'Más',
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
                    titulo: 'Mis Alertas',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaAlertas(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _itemMenu(
                    context,
                    icono: Icons.translate,
                    titulo: 'Traductor y Frases',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaTraduccion(),
                        ),
                      );
                    },
                  ),
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
                    titulo: 'Sobre la app',
                    onTap: () {},
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.settings_outlined,
                    titulo: 'Configuración',
                    onTap: () {},
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Icon(icono, color: AppColores.marronOscuro),
      title: Text(
        titulo,
        style: const TextStyle(fontSize: 15, color: AppColores.marronOscuro),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColores.grisTexto,
      ),
      onTap: onTap,
    );
  }
}
