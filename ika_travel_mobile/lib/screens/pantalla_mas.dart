import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../models/usuario_modelo.dart';
import '../services/auth_service.dart';
import 'pantalla_favoritos.dart';
import 'pantalla_alertas.dart';
import 'pantalla_configuracion.dart';
import 'pantalla_configurar_alertas.dart';
import 'pantalla_login.dart';
import 'pantalla_planer.dart';
import 'pantalla_seguimiento_destino.dart';
import 'pantalla_sos.dart';

class PantallaMas extends StatelessWidget {
  const PantallaMas({super.key});

  void _mostrarInfo(BuildContext context, String titulo, String contenido) {
    final colorTexto = TemaApp.texto(context);
    final colorFondo = TemaApp.tarjeta(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorFondo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            titulo,
            style: TextStyle(fontWeight: FontWeight.bold, color: colorTexto),
          ),
          content: Text(contenido, style: TextStyle(color: colorTexto)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Entendido',
                style: TextStyle(
                  color: AppColores.naranjaBoton,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmarCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TemaApp.tarjeta(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '¿Cerrar sesión?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: TemaApp.texto(ctx),
            ),
          ),
          content: Text(
            'Se cerrará tu sesión actual en este dispositivo.',
            style: TextStyle(color: TemaApp.textoSecundario(ctx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthService().cerrarSesion();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const PantallaLogin()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTarjetaPerfil(BuildContext context) {
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSec = TemaApp.textoSecundario(context);

    return ValueListenableBuilder<UsuarioModelo?>(
      valueListenable: AuthService().usuarioNotifier,
      builder: (context, usuario, _) {
        final esInvitado = usuario == null || usuario.esInvitado;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorTarjeta,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: esInvitado
                    ? Colors.grey.shade300
                    : AppColores.naranjaBoton,
                child: Text(
                  esInvitado ? '?' : usuario.iniciales,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: esInvitado ? Colors.grey.shade700 : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esInvitado ? 'Modo Invitado' : usuario.fullName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      esInvitado
                          ? 'Inicia sesión para sincronizar datos'
                          : usuario.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorTextoSec,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: esInvitado
                            ? Colors.grey.withOpacity(0.15)
                            : const Color(0xFF2E7D32).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        esInvitado ? 'Sin cuenta' : 'Turista verificado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: esInvitado
                              ? Colors.grey.shade700
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (esInvitado)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.naranjaBoton,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PantallaLogin(abrirComoModal: true),
                      ),
                    );
                  },
                  child: const Text(
                    'Ingresar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFD32F2F),
                    size: 22,
                  ),
                  onPressed: () => _confirmarCerrarSesion(context),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorTexto, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Más opciones',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Tarjeta de perfil de usuario
                  _buildTarjetaPerfil(context),

                  _itemMenu(
                    context,
                    icono: Icons.route,
                    titulo: 'Planificador de viajes',
                    subtitulo: 'Rutas por destinos, distancia y tiempos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaPlaner(),
                        ),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.notifications_active_outlined,
                    titulo: 'Alertas inteligentes',
                    subtitulo: 'Avisos en tiempo real y alternativas',
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
                    titulo: 'Seguimiento de destinos',
                    subtitulo: 'Historial y evolución de condiciones',
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
                  _itemMenu(
                    context,
                    icono: Icons.shield_outlined,
                    titulo: 'Asistencia y SOS',
                    subtitulo: 'Contactos y números de emergencia',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaSos(),
                        ),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.tune,
                    titulo: 'Configuración de alertas',
                    subtitulo: 'Canales y tipos de notificación',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PantallaConfigurarAlertas(),
                        ),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.favorite_border,
                    titulo: 'Lugares favoritos',
                    subtitulo: 'Tus actividades guardadas',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaFavoritos(),
                        ),
                      );
                    },
                  ),
                  Divider(color: colorTextoSecundario.withOpacity(0.3)),
                  _itemMenu(
                    context,
                    icono: Icons.settings_outlined,
                    titulo: 'Configuración general',
                    subtitulo: 'Idioma y tema visual',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaConfiguracion(),
                        ),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.schedule,
                    titulo: 'Mejor hora para visitar',
                    onTap: () => _mostrarInfo(
                      context,
                      'Mejor hora para visitar',
                      'La mejor época para visitar Ica es entre los meses de mayo y octubre, ya que el clima es más fresco y agradable para realizar actividades al aire libre.',
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.lightbulb_outline,
                    titulo: 'Consejos para el turista',
                    onTap: () => _mostrarInfo(
                      context,
                      'Consejos para el turista',
                      '• Lleva protector solar y gafas de sol.\n• Hidrátate constantemente.\n• Usa ropa cómoda y calzado adecuado para arena.\n• Lleva efectivo para los locales.\n• Respeta la flora y fauna local.',
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.info_outline,
                    titulo: 'Sobre la app',
                    onTap: () => _mostrarInfo(
                      context,
                      'Sobre Ika Travel',
                      'Ika Travel es tu compañero ideal para descubrir lo mejor de Ica. Te ayudamos a planificar tus actividades basándonos en el clima en tiempo real.\n\nVersión 1.0.0',
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.share_outlined,
                    titulo: 'Compartir app',
                    onTap: () => _mostrarInfo(
                      context,
                      'Compartir app',
                      '¡Comparte Ika Travel con tus amigos y familiares para que también disfruten de la mejor experiencia en Ica!',
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.contact_support_outlined,
                    titulo: 'Contacto o ayuda',
                    onTap: () => _mostrarInfo(
                      context,
                      'Contacto o ayuda',
                      '¿Tienes alguna duda o problema?\n\nEscríbenos a:\nsoporte@ikatravel.com\n\nO llámanos al:\n+51 987 654 321',
                    ),
                  ),

                  const SizedBox(height: 10),
                  // Botón Cerrar Sesión al final
                  ValueListenableBuilder<UsuarioModelo?>(
                    valueListenable: AuthService().usuarioNotifier,
                    builder: (context, usuario, _) {
                      if (usuario == null || usuario.esInvitado) {
                        return const SizedBox.shrink();
                      }
                      return TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _confirmarCerrarSesion(context),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
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
    String? subtitulo,
    required VoidCallback onTap,
  }) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColores.naranjaBoton.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icono, color: AppColores.naranjaBoton, size: 22),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorTexto,
        ),
      ),
      subtitle: subtitulo != null
          ? Text(
              subtitulo,
              style: TextStyle(
                fontSize: 12,
                color: colorTextoSecundario,
              ),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: colorTextoSecundario,
      ),
      onTap: onTap,
    );
  }
}
