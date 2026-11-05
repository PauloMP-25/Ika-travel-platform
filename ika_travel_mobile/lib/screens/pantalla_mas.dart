import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../config/traducciones_scope.dart';
import '../models/usuario_modelo.dart';
import '../services/auth_service.dart';
import 'pantalla_favoritos.dart';
import 'pantalla_alertas.dart';
import 'pantalla_configuracion.dart';
import 'pantalla_configurar_alertas.dart';
import 'pantalla_login.dart';
import 'pantalla_planer.dart';
import 'pantalla_prestadores.dart';
import 'pantalla_reporte_incidencia.dart';
import 'pantalla_seguimiento_destino.dart';
import 'pantalla_sos.dart';
import 'pantalla_traduccion.dart';
import '../widgets/dialogo_preferencias_turista.dart';

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
              child: Text(
                context.tr('entendido'),
                style: const TextStyle(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.tr('confirmar_cerrar_sesion'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: TemaApp.texto(ctx),
            ),
          ),
          content: Text(
            context.tr('confirmar_cerrar_sesion_msg'),
            style: TextStyle(color: TemaApp.textoSecundario(ctx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancelar')),
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
              child: Text(context.tr('cerrar_sesion')),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoEditarTelefono(
    BuildContext context,
    UsuarioModelo usuario,
  ) {
    final telCtrl = TextEditingController(text: usuario.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TemaApp.tarjeta(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.phone_android_rounded,
                color: AppColores.naranjaBoton,
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('mi_telefono'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: TemaApp.texto(ctx),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('telefono_msg'),
                  style: TextStyle(
                    fontSize: 13,
                    color: TemaApp.textoSecundario(ctx),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: TemaApp.texto(ctx)),
                  decoration: InputDecoration(
                    labelText: context.tr('numero_celular'),
                    hintText: '+51 987 654 321',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return context.tr('error_numero_vacio');
                    }
                    if (v.trim().length < 6) {
                      return context.tr('error_numero_invalido');
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancelar')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaBoton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  await AuthService().actualizarPerfil(
                    phone: telCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('telefono_actualizado')),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  }
                }
              },
              child: Text(context.tr('guardar')),
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
                color: Colors.black.withValues(alpha: 0.05),
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
                      esInvitado
                          ? context.tr('modo_invitado')
                          : usuario.fullName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      esInvitado
                          ? context.tr('inicia_sesion_sincronizar')
                          : usuario.email,
                      style: TextStyle(fontSize: 12, color: colorTextoSec),
                    ),
                    if (!esInvitado &&
                        usuario.phone != null &&
                        usuario.phone!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        usuario.phone!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: esInvitado
                            ? Colors.grey.withValues(alpha: 0.15)
                            : const Color(0xFF2E7D32).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        esInvitado
                            ? context.tr('sin_cuenta')
                            : context.tr('turista_verificado'),
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
                        builder: (_) =>
                            const PantallaLogin(abrirComoModal: true),
                      ),
                    );
                  },
                  child: Text(
                    context.tr('ingresar'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.tr('mi_telefono'),
                      icon: const Icon(
                        Icons.phone_android_rounded,
                        color: Color(0xFF2E7D32),
                        size: 22,
                      ),
                      onPressed: () =>
                          _mostrarDialogoEditarTelefono(context, usuario),
                    ),
                    IconButton(
                      tooltip: context.tr('mis_preferencias'),
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: AppColores.naranjaBoton,
                        size: 22,
                      ),
                      onPressed: () =>
                          DialogoPreferenciasTurista.mostrar(context, usuario),
                    ),
                    IconButton(
                      tooltip: context.tr('cerrar_sesion'),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFD32F2F),
                        size: 22,
                      ),
                      onPressed: () => _confirmarCerrarSesion(context),
                    ),
                  ],
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
                      context.tr('mas_opciones'),
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
                  _buildTarjetaPerfil(context),

                  _itemMenu(
                    context,
                    icono: Icons.route,
                    titulo: context.tr('planificador_viajes'),
                    subtitulo: context.tr('planificador_viajes_sub'),
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
                    titulo: context.tr('alertas_inteligentes'),
                    subtitulo: context.tr('alertas_inteligentes_sub'),
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
                    titulo: context.tr('seguimiento_destinos'),
                    subtitulo: context.tr('seguimiento_destinos_sub'),
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
                    titulo: context.tr('asistencia_sos'),
                    subtitulo: context.tr('asistencia_sos_sub'),
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
                    icono: Icons.verified_user_outlined,
                    titulo: context.tr('servicios_formalizados'),
                    subtitulo: context.tr('servicios_formalizados_sub'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaPrestadores(),
                        ),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.campaign_outlined,
                    titulo: context.tr('reporte_incidencias'),
                    subtitulo: context.tr('reporte_incidencias_sub'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PantallaReporteIncidencia(),
                        ),
                      );
                    },
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.tune,
                    titulo: context.tr('configuracion_alertas'),
                    subtitulo: context.tr('configuracion_alertas_sub'),
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
                    icono: Icons.translate,
                    titulo: context.tr('traduccion_frasebook'),
                    subtitulo: context.tr('traduccion_frasebook_sub'),
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
                    icono: Icons.favorite_border,
                    titulo: context.tr('lugares_favoritos'),
                    subtitulo: context.tr('lugares_favoritos_sub'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaFavoritos(),
                        ),
                      );
                    },
                  ),
                  Divider(color: colorTextoSecundario.withValues(alpha: 0.3)),
                  _itemMenu(
                    context,
                    icono: Icons.settings_outlined,
                    titulo: context.tr('configuracion_general'),
                    subtitulo: context.tr('configuracion_general_sub'),
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
                    titulo: context.tr('mejor_hora'),
                    onTap: () => _mostrarInfo(
                      context,
                      context.tr('mejor_hora'),
                      context.tr('mejor_hora_msg'),
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.lightbulb_outline,
                    titulo: context.tr('consejos'),
                    onTap: () => _mostrarInfo(
                      context,
                      context.tr('consejos'),
                      context.tr('consejos_msg'),
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.info_outline,
                    titulo: context.tr('sobre_app'),
                    onTap: () => _mostrarInfo(
                      context,
                      context.tr('sobre_app_titulo'),
                      context.tr('sobre_app_msg'),
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.share_outlined,
                    titulo: context.tr('compartir_app'),
                    onTap: () => _mostrarInfo(
                      context,
                      context.tr('compartir_app'),
                      context.tr('compartir_app_msg'),
                    ),
                  ),
                  _itemMenu(
                    context,
                    icono: Icons.contact_support_outlined,
                    titulo: context.tr('contacto'),
                    onTap: () => _mostrarInfo(
                      context,
                      context.tr('contacto'),
                      context.tr('contacto_msg'),
                    ),
                  ),

                  const SizedBox(height: 10),
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
                        label: Text(
                          context.tr('cerrar_sesion'),
                          style: const TextStyle(
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
          color: AppColores.naranjaBoton.withValues(alpha: 0.1),
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
              style: TextStyle(fontSize: 12, color: colorTextoSecundario),
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
