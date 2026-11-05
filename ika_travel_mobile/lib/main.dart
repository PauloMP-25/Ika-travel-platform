import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/tema.dart';
import 'config/tema_manager.dart';
import 'config/idioma_manager.dart';
import 'config/traducciones.dart';
import 'config/traducciones_scope.dart';
import 'models/usuario_modelo.dart';
import 'screens/main_scaffold.dart';
import 'screens/pantalla_login.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().inicializar();
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
                // Tu lógica de sesión intacta
                home: ValueListenableBuilder<UsuarioModelo?>(
                  valueListenable: AuthService().usuarioNotifier,
                  builder: (context, usuario, _) {
                    if (usuario != null) {
                      return const MainScaffold();
                    }
                    return const PantallaLogin();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
