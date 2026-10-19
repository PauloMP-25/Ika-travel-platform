import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/idioma_manager.dart'; // 👈 Nuevo
import '../config/traducciones.dart'; // 👈 Nuevo
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
  int _indiceActual = 0;

  void _cambiarPestana(int nuevoIndice) {
    setState(() {
      _indiceActual = nuevoIndice;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lista de pantallas
    final List<Widget> pantallas = [
      const PantallaInicio(),
      PantallaActividades(onVolverInicio: () => _cambiarPestana(0)),
      const PantallaMapa(),
      const PantallaPronostico(),
      const PantallaFavoritos(),
    ];

    // 👇 Escuchamos el idioma actual para traducir los textos
    return ValueListenableBuilder<Locale>(
      valueListenable: idiomaActivo,
      builder: (context, locale, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          body: IndexedStack(index: _indiceActual, children: pantallas),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark
                ? const Color(0xFF2C2C2C)
                : Colors.white, // 👈 Se adapta al modo oscuro
            selectedItemColor: AppColores.naranjaBoton,
            unselectedItemColor: Colors.grey,
            currentIndex: _indiceActual,
            onTap: _cambiarPestana,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: Traducciones.get('inicio', locale), // 👈 Traducido
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.grid_view_outlined),
                activeIcon: const Icon(Icons.grid_view),
                label: Traducciones.get('actividades', locale), // 👈 Traducido
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.location_on_outlined),
                activeIcon: const Icon(Icons.location_on),
                label: Traducciones.get('mapa', locale), // 👈 Traducido
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.wb_cloudy_outlined),
                activeIcon: const Icon(Icons.wb_cloudy),
                label: Traducciones.get('pronostico', locale), // 👈 Traducido
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.favorite_border),
                activeIcon: const Icon(Icons.favorite),
                label: Traducciones.get('favoritos', locale), // 👈 Traducido
              ),
            ],
          ),
        );
      },
    );
  }
}
