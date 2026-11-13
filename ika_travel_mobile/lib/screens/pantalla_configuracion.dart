import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/tema_manager.dart';
import '../config/colores_tema.dart';
import '../config/idioma_manager.dart';
import '../config/traducciones.dart';
import '../config/traducciones_scope.dart';
import '../services/auth_service.dart';
import '../widgets/dialogo_preferencias_turista.dart';
import 'pantalla_login.dart';
import 'pantalla_admin_dircetur.dart';

class PantallaConfiguracion extends StatefulWidget {
  const PantallaConfiguracion({super.key});

  @override
  State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
  bool _notificacionesActivas = true;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;
    final colorTexto = TemaApp.texto(context);
    final colorFondoTarjeta = TemaApp.tarjeta(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    final usuarioActual = AuthService().usuarioActual;
    final esAdmin = usuarioActual?.email == 'admin@ikatravel.com';

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorTexto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('configuracion'),
          style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr('preferencias'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: colorFondoTarjeta,
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    context.tr('notificaciones'),
                    style: TextStyle(color: colorTexto),
                  ),
                  subtitle: Text(
                    context.tr('recibir_alertas'),
                    style: TextStyle(fontSize: 12, color: colorTextoSecundario),
                  ),
                  activeColor: AppColores.naranjaBoton,
                  value: _notificacionesActivas,
                  onChanged: (bool value) {
                    setState(() {
                      _notificacionesActivas = value;
                    });
                  },
                ),
                Divider(
                  height: 1,
                  color: colorTextoSecundario.withValues(alpha: 0.2),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: modoOscuroActivo,
                  builder: (context, isDarkMode, child) {
                    return SwitchListTile(
                      title: Text(
                        context.tr('modo_oscuro'),
                        style: TextStyle(color: colorTexto),
                      ),
                      subtitle: Text(
                        context.tr('cambiar_apariencia'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorTextoSecundario,
                        ),
                      ),
                      activeColor: AppColores.naranjaBoton,
                      value: isDarkMode,
                      onChanged: (bool value) {
                        toggleModoOscuro(value);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            context.tr('region'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: colorFondoTarjeta,
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.language, color: colorTexto),
              title: Text(
                context.tr('idioma_app'),
                style: TextStyle(color: colorTexto),
              ),
              trailing: Text(
                Traducciones.nombresIdioma[locale.languageCode] ?? 'Español',
                style: TextStyle(color: colorTextoSecundario),
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: colorFondoTarjeta,
                  useSafeArea: true,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (modalContext) {
                    return SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('seleccionar_idioma'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorTexto,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...Traducciones.supportedLocales.map((loc) {
                                final nombre =
                                    Traducciones.nombresIdioma[loc
                                        .languageCode] ??
                                    loc.languageCode;
                                final isSelected =
                                    loc.languageCode == locale.languageCode;

                                return ListTile(
                                  title: Text(
                                    nombre,
                                    style: TextStyle(color: colorTexto),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: AppColores.naranjaBoton,
                                        )
                                      : null,
                                  onTap: () {
                                    cambiarIdioma(loc.languageCode);
                                    Navigator.pop(modalContext);
                                  },
                                );
                              }),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          Text(
            context.tr('cuenta'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: colorFondoTarjeta,
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.tune_rounded,
                    color: AppColores.naranjaBoton,
                  ),
                  title: Text(
                    context.tr('preferencias_turista'),
                    style: TextStyle(
                      color: colorTexto,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    context.tr('preferencias_turista_sub'),
                    style: TextStyle(fontSize: 12, color: colorTextoSecundario),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    final usuario = AuthService().usuarioActual;
                    if (usuario != null && !usuario.esInvitado) {
                      DialogoPreferenciasTurista.mostrar(context, usuario);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr('iniciar_sesion_para_prefs'),
                          ),
                          action: SnackBarAction(
                            label: context.tr('ingresar'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PantallaLogin(abrirComoModal: true),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
                Divider(
                  height: 1,
                  color: colorTextoSecundario.withValues(alpha: 0.15),
                ),

                // --- BOTÓN CONDICIONAL: SOLO PARA ADMINS ---
                if (esAdmin) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.blue,
                    ),
                    title: const Text(
                      'Panel DIRCETUR',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Gestión de agencias y reportes',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PantallaAdminDircetur(),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: colorTextoSecundario.withValues(alpha: 0.15),
                  ),
                ],
                // -------------------------------------------

                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: Text(
                    context.tr('cerrar_sesion'),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colorFondoTarjeta,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          context.tr('confirmar_cerrar_sesion'),
                          style: TextStyle(
                            color: colorTexto,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          context.tr('confirmar_cerrar_sesion_msg'),
                          style: TextStyle(color: colorTextoSecundario),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(context.tr('cancelar')),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(context.tr('cerrar_sesion')),
                          ),
                        ],
                      ),
                    );

                    if (confirmar == true && context.mounted) {
                      await AuthService().cerrarSesion();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PantallaLogin(),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
