import 'config/navegacion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'config/contenedor_web.dart';
import 'config/escala_texto.dart';
import 'config/tema.dart';
import 'config/tema_manager.dart';
import 'config/idioma_manager.dart';
import 'config/traducciones.dart';
import 'config/traducciones_scope.dart';
import 'models/usuario_modelo.dart';
import 'screens/main_scaffold.dart';
import 'screens/pantalla_bienvenida.dart';
import 'screens/pantalla_permisos.dart';
import 'services/auth_service.dart';
import 'services/preferencias_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().inicializar();
  await PreferenciasService().cargar();
  runApp(const IkaTravelApp());
}

class IkaTravelApp extends StatelessWidget {
  const IkaTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: idiomaActivo,
      builder: (context, locale, _) {
        return TraduccionesScope(
          notifier: idiomaActivo,

          child: ValueListenableBuilder<bool>(
            valueListenable: modoOscuroActivo,
            builder: (context, isDarkMode, child) {
              return MaterialApp(
                navigatorKey: NavegacionService.navigatorKey,
                title: 'Ika Travel',
                debugShowCheckedModeBanner: false,

                locale: locale,
                supportedLocales: Traducciones.supportedLocales,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                localeResolutionCallback: (_, __) => idiomaActivo.value,

                themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
                theme: ThemeData(
                  scaffoldBackgroundColor: AppColores.arenaFondo,
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColores.naranjaBoton,
                    brightness: Brightness.light,
                  ),
                ),
                darkTheme: ThemeData(
                  scaffoldBackgroundColor: const Color(0xFF1E1E1E),
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColores.naranjaBoton,
                    brightness: Brightness.dark,
                  ),
                ),
                // Tope a la letra del sistema (EscalaTexto) y, solo en web,
                // la app centrada en una columna de ancho de teléfono
                // (ContenedorWeb). En Android no cambia nada.
                builder: (context, child) => ContenedorWeb(
                  child: EscalaTexto.aplicar(context, child),
                ),
                home: const _GateArranque(),
              );
            },
          ),
        );
      },
    );
  }
}

/// Decide qué pantalla ve el usuario al abrir la app.
///
/// El orden importa: **primero la cuenta, después los permisos**.
/// 1. Sin sesión → pantalla de bienvenida (de ahí a registro o login).
/// 2. Con sesión y sin permisos aceptados → pantalla de permisos. Pedirlos
///    recién aquí tiene sentido: el usuario ya sabe qué es la app y entiende
///    para qué le pedimos su ubicación.
/// 3. Con sesión y permisos → la app.
class _GateArranque extends StatefulWidget {
  const _GateArranque();

  @override
  State<_GateArranque> createState() => _GateArranqueState();
}

class _GateArranqueState extends State<_GateArranque> {
  bool _permisosListos = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UsuarioModelo?>(
      valueListenable: AuthService().usuarioNotifier,
      builder: (context, usuario, _) {
        if (usuario == null) return const PantallaBienvenida();

        // En web no hay permisos del sistema que pedir: el navegador los
        // pide solo (ubicación, micrófono) la primera vez que se usan, y
        // SMS o llamadas no existen. Mostrar la pantalla ahí solo estorba.
        if (!kIsWeb && !_permisosListos) {
          return PantallaPermisos(
            onCompletado: () {
              if (mounted) setState(() => _permisosListos = true);
            },
          );
        }

        return const MainScaffold();
      },
    );
  }
}
