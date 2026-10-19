import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/navegacion_service.dart';
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

    return ValueListenableBuilder<int>(
      valueListenable: NavegacionService.indiceTabNotifier,
      builder: (context, indiceActual, _) {
        return Scaffold(
          body: IndexedStack(index: indiceActual, children: pantallas),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColores.naranjaBoton,
            unselectedItemColor: Colors.grey,
            currentIndex: indiceActual,
            onTap: (nuevoIndice) {
              NavegacionService.indiceTabNotifier.value = nuevoIndice;
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined),
                activeIcon: Icon(Icons.grid_view),
                label: 'Actividades',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.location_on_outlined),
                activeIcon: Icon(Icons.location_on),
                label: 'Mapa',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.wb_cloudy_outlined),
                activeIcon: Icon(Icons.wb_cloudy),
                label: 'Pronóstico',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border),
                activeIcon: Icon(Icons.favorite),
                label: 'Favoritos',
              ),
            ],
          ),
        );
      },
    );
  }
}
