import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/favoritos_manager.dart';
import 'pantalla_detalle.dart';
import 'pantalla_alertas.dart';

class PantallaFavoritos extends StatelessWidget {
  const PantallaFavoritos({super.key});

  @override
  Widget build(BuildContext context) {
    final bool puedeVolver = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Título con flecha condicional
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 👇 Si puede volver, muestra la flecha. Si no, un espacio vacío
                  if (puedeVolver)
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColores.marronOscuro,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 48),

                  const Expanded(
                    child: Text(
                      'Favoritos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                  ), // Espacio para equilibrar el título
                ],
              ),
            ),

            // 2. Lista de Favoritos (Escuchando los cambios)
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: listaFavoritos,
                builder: (context, favoritos, child) {
                  if (favoritos.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aún no tienes favoritos ❤️',
                        style: TextStyle(
                          color: AppColores.grisTexto,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColores.marronOscuro,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  'Excelente • ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '92/100',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColores.grisTexto,
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
              ),
            ),

            // 3. Botón de alertas
            Padding(
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
                  label: const Text(
                    'Recibir alertas para favoritos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
