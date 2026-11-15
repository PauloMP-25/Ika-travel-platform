import 'package:flutter/material.dart';

import '../config/favoritos_manager.dart';
import '../config/tema.dart';
import '../config/navegacion_service.dart';
import '../config/traducciones_scope.dart';
import '../services/preferencias_service.dart';
import '../widgets/modal_preferencias.dart';
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
  // Evita que el modal de preferencias se abra dos veces si se montan varias
  // instancias de MainScaffold durante la transición de login.
  static bool _preferenciasPreguntadas = false;

  @override
  void initState() {
    super.initState();
    // La primera vez que el usuario entra, le preguntamos sus gustos para
    // que la IA personalice las recomendaciones.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!PreferenciasService().yaCompletado && !_preferenciasPreguntadas) {
        _preferenciasPreguntadas = true;
        ModalPreferencias.mostrar(context);
      }
    });

    // Recupera los favoritos guardados en el servidor (otro teléfono o
    // reinstalación). Si no hay sesión o conexión, no hace nada.
    sincronizarFavoritosDesdeServidor();
  }

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

    // Cada pestaña tiene su propio color vivo, para que se distinga de un
    // vistazo cuál está activa.
    final pestanas = <_Pestana>[
      _Pestana(
        icono: Icons.home_outlined,
        iconoActivo: Icons.home_rounded,
        etiqueta: context.tr('inicio'),
        color: AppColores.naranjaBoton,
      ),
      _Pestana(
        icono: Icons.grid_view_outlined,
        iconoActivo: Icons.grid_view_rounded,
        etiqueta: context.tr('actividades'),
        color: const Color(0xFFFFB300), // amarillo duna
      ),
      _Pestana(
        icono: Icons.location_on_outlined,
        iconoActivo: Icons.location_on_rounded,
        etiqueta: context.tr('mapa'),
        color: const Color(0xFF27C06B), // verde oasis
      ),
      _Pestana(
        icono: Icons.wb_cloudy_outlined,
        iconoActivo: Icons.wb_cloudy_rounded,
        etiqueta: context.tr('pronostico'),
        color: const Color(0xFF2BB7E3), // celeste
      ),
      _Pestana(
        icono: Icons.translate_outlined,
        iconoActivo: Icons.translate_rounded,
        etiqueta: context.tr('traducir'),
        color: AppColores.turquesaOasis,
      ),
    ];

    return ValueListenableBuilder<int>(
      valueListenable: NavegacionService.indiceTabNotifier,
      builder: (context, indiceActual, _) {
        return Scaffold(
          body: IndexedStack(index: indiceActual, children: pantallas),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.09),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  children: [
                    for (var i = 0; i < pestanas.length; i++)
                      Expanded(
                        child: _BotonPestana(
                          pestana: pestanas[i],
                          activo: indiceActual == i,
                          esOscuro: isDark,
                          onTap: () =>
                              NavegacionService.indiceTabNotifier.value = i,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Definición visual de una pestaña de la barra inferior.
class _Pestana {
  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
  final Color color;

  const _Pestana({
    required this.icono,
    required this.iconoActivo,
    required this.etiqueta,
    required this.color,
  });
}

/// Botón de la barra inferior: cuando está activo se colorea y se enciende
/// una píldora de fondo con su color.
class _BotonPestana extends StatelessWidget {
  final _Pestana pestana;
  final bool activo;
  final bool esOscuro;
  final VoidCallback onTap;

  const _BotonPestana({
    required this.pestana,
    required this.activo,
    required this.esOscuro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorInactivo = esOscuro ? Colors.white54 : Colors.grey.shade500;
    final color = activo ? pestana.color : colorInactivo;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: activo
              ? pestana.color.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activo ? pestana.iconoActivo : pestana.icono,
              color: color,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              pestana.etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
