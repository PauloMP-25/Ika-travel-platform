import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/navegacion_service.dart';
import '../config/idioma_manager.dart';
import '../config/traducciones.dart';
import 'pantalla_inicio.dart';
import 'pantalla_actividades.dart';
import 'pantalla_pronostico.dart';
import 'pantalla_mapa.dart';
import 'pantalla_favoritos.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  @override
  Widget build(BuildContext context) {
    // Lista de pantallas principales que conservan la navegación inferior
    final List<Widget> pantallas = [
      const PantallaInicio(),
      PantallaActividades(onVolverInicio: () => NavegacionService.irAInicio()),
      const PantallaMapa(),
      const PantallaPronostico(),
      const PantallaFavoritos(),
    ];

    return ValueListenableBuilder<Locale>(
      valueListenable: idiomaActivo,
      builder: (context, locale, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ValueListenableBuilder<int>(
          valueListenable: NavegacionService.indiceTabNotifier,
          builder: (context, indiceActual, _) {
            return Scaffold(
              body: IndexedStack(index: indiceActual, children: pantallas),
              bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.white,
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
                    label: Traducciones.get('inicio', locale),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.grid_view_outlined),
                    activeIcon: const Icon(Icons.grid_view),
                    label: Traducciones.get('actividades', locale),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.location_on_outlined),
                    activeIcon: const Icon(Icons.location_on),
                    label: Traducciones.get('mapa', locale),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.wb_cloudy_outlined),
                    activeIcon: const Icon(Icons.wb_cloudy),
                    label: Traducciones.get('pronostico', locale),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.favorite_border),
                    activeIcon: const Icon(Icons.favorite),
                    label: Traducciones.get('favoritos', locale),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
