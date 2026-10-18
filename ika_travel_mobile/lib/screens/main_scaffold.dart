import 'package:flutter/material.dart';

import '../config/tema.dart';
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

    return Scaffold(
      body: IndexedStack(index: _indiceActual, children: pantallas),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColores.naranjaBoton,
        unselectedItemColor: Colors.grey,
        currentIndex: _indiceActual,
        onTap: _cambiarPestana,
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
  }
}
