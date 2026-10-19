import 'package:flutter/material.dart';

import 'screens/main_scaffold.dart';
import 'config/tema.dart';
import 'config/tema_manager.dart';

void main() {
  runApp(const IkaTravelApp());
}

class IkaTravelApp extends StatelessWidget {
  const IkaTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: modoOscuroActivo,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'Ika Travel',
          debugShowCheckedModeBanner: false,

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
            // Un fondo oscuro elegante
            scaffoldBackgroundColor: const Color(0xFF1E1E1E),
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColores.naranjaBoton,
              brightness: Brightness.dark,
            ),
          ),

          home: const MainScaffold(),
        );
      },
    );
  }
}
