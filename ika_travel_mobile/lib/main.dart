import 'package:flutter/material.dart';

import 'screens/main_scaffold.dart';
import 'config/tema.dart';

void main() {
  runApp(const IkaTravelApp());
}

class IkaTravelApp extends StatelessWidget {
  const IkaTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ika Travel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColores.arenaFondo,
        useMaterial3: true,
      ),
      home: const MainScaffold(),
    );
  }
}
