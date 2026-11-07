import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/favoritos_manager.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/usuario_modelo.dart';
import '../services/auth_service.dart';
import 'pantalla_alertas.dart';
import 'pantalla_detalle.dart';
import 'pantalla_login.dart';

class PantallaFavoritos extends StatelessWidget {
  const PantallaFavoritos({super.key});

  @override
  Widget build(BuildContext context) {
    final bool puedeVolver = Navigator.canPop(context);

    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

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
                  if (puedeVolver)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colorTexto, size: 28),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      context.tr('favoritos'),
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
              child: ValueListenableBuilder<UsuarioModelo?>(
                valueListenable: AuthService().usuarioNotifier,
                builder: (context, usuario, _) {
                  final esInvitado = usuario == null || usuario.esInvitado;
                  if (esInvitado) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColores.naranjaBoton.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_border,
                                size: 50,
                                color: AppColores.naranjaBoton,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('guarda_favoritos'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('guarda_favoritos_msg'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorTextoSecundario,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.naranjaBoton,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.login, size: 18),
                              label: Text(
                                context.tr('iniciar_sesion'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PantallaLogin(
                                      abrirComoModal: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ValueListenableBuilder(
                    valueListenable: listaFavoritos,
                    builder: (context, favoritos, child) {
                      if (favoritos.isEmpty) {
                        return Center(
                          child: Text(
                            context.tr('sin_favoritos'),
                            style: TextStyle(
                              color: colorTextoSecundario,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: favoritos.length,
                        itemBuilder: (context, index) {
                          final actividad = favoritos[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: colorTarjeta,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(10),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    actividad['imagen'],
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: Text(
                                  actividad['titulo'].replaceAll('\n', ' '),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: colorTexto,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      '${context.tr('excelente')} • ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '92/100',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorTextoSecundario,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.favorite,
                                    color: AppColores.naranjaBoton,
                                  ),
                                  onPressed: () {
                                    toggleFavorito(actividad);
                                  },
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PantallaDetalle(
                                        titulo: actividad['titulo'],
                                        subtitulo: actividad['subtitulo'],
                                        imagenes: List<String>.from(
                                          actividad['imagenes_detalle'],
                                        ),
                                        // Pasa el id guardado en el favorito
                                        atractivoId: actividad['id']
                                            ?.toString(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            ValueListenableBuilder<UsuarioModelo?>(
              valueListenable: AuthService().usuarioNotifier,
              builder: (context, usuario, _) {
                if (usuario == null || usuario.esInvitado) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.marronOscuro,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PantallaAlertas(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                      ),
                      label: Text(
                        context.tr('recibir_alertas_favoritos'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
