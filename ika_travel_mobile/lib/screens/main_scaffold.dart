import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/navegacion_service.dart';
import '../config/traducciones_scope.dart';
import 'pantalla_inicio.dart';
import 'pantalla_actividades.dart';
import 'pantalla_pronostico.dart';
import 'pantalla_mapa.dart';
import 'pantalla_traduccion.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  @override
  Widget build(BuildContext context) {
    final List<Widget> pantallas = [
      PantallaInicio(),
      PantallaActividades(onVolverInicio: () => NavegacionService.irAInicio()),
      PantallaMapa(),
      PantallaPronostico(),
      // Favoritos sigue accesible desde el menú "Más".
      const PantallaTraduccion(comoPestana: true),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<int>(
      valueListenable: NavegacionService.indiceTabNotifier,
      builder: (context, indiceActual, _) {
        return Scaffold(
          body: IndexedStack(index: indiceActual, children: pantallas),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            selectedItemColor: AppColores.naranjaBoton,
            unselectedItemColor: Colors.grey,
            currentIndex: indiceActual,
            onTap: (nuevoIndice) {
              NavegacionService.indiceTabNotifier.value = nuevoIndice;
            },
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: context.tr('inicio'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.grid_view_outlined),
                activeIcon: const Icon(Icons.grid_view),
                label: context.tr('actividades'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.location_on_outlined),
                activeIcon: const Icon(Icons.location_on),
                label: context.tr('mapa'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.wb_cloudy_outlined),
                activeIcon: const Icon(Icons.wb_cloudy),
                label: context.tr('pronostico'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.translate_outlined),
                activeIcon: const Icon(Icons.translate),
                label: context.tr('traducir'),
              ),
            ],
          ),
        );
      },
    );
  }
}
