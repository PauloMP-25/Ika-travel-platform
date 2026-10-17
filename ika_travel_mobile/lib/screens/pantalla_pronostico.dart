import 'package:flutter/material.dart';

import '../config/tema.dart';

class PantallaPronostico extends StatefulWidget {
  const PantallaPronostico({super.key});

  @override
  State<PantallaPronostico> createState() => _PantallaPronosticoState();
}

class _PantallaPronosticoState extends State<PantallaPronostico> {
  // Opción seleccionada (0 = Hoy, 1 = Mañana, 2 = 7 días)
  int _opcionSeleccionada = 0;

  // Datos de HOY
  final List<Map<String, dynamic>> _datosHoy = [
    {
      'hora': '08:00',
      'icono': Icons.wb_sunny,
      'condicion': 'Excelente',
      'indice': 90,
    },
    {
      'hora': '11:00',
      'icono': Icons.wb_sunny,
      'condicion': 'Excelente',
      'indice': 92,
    },
    {
      'hora': '14:00',
      'icono': Icons.wb_cloudy,
      'condicion': 'Bueno',
      'indice': 75,
    },
    {'hora': '17:00', 'icono': Icons.air, 'condicion': 'Regular', 'indice': 55},
    {
      'hora': '20:00',
      'icono': Icons.nightlight_round,
      'condicion': 'Bueno',
      'indice': 70,
    },
  ];

  // Datos de MAÑANA
  final List<Map<String, dynamic>> _datosManana = [
    {'hora': '08:00', 'icono': Icons.cloud, 'condicion': 'Bueno', 'indice': 80},
    {
      'hora': '11:00',
      'icono': Icons.wb_sunny,
      'condicion': 'Excelente',
      'indice': 95,
    },
    {
      'hora': '14:00',
      'icono': Icons.wb_sunny,
      'condicion': 'Excelente',
      'indice': 88,
    },
    {'hora': '17:00', 'icono': Icons.cloud, 'condicion': 'Bueno', 'indice': 65},
    {
      'hora': '20:00',
      'icono': Icons.nightlight_round,
      'condicion': 'Regular',
      'indice': 50,
    },
  ];

  // Datos de 7 DÍAS (Agrupado por días)
  final List<Map<String, dynamic>> _datos7Dias = [
    {
      'hora': 'Lunes',
      'icono': Icons.wb_sunny,
      'condicion': 'Excelente',
      'indice': 90,
    },
    {
      'hora': 'Martes',
      'icono': Icons.wb_sunny,
      'condicion': 'Excelente',
      'indice': 85,
    },
    {
      'hora': 'Miércoles',
      'icono': Icons.wb_cloudy,
      'condicion': 'Bueno',
      'indice': 70,
    },
    {
      'hora': 'Jueves',
      'icono': Icons.air,
      'condicion': 'Regular',
      'indice': 55,
    },
    {
      'hora': 'Viernes',
      'icono': Icons.wb_sunny,
      'condicion': 'Excelente',
      'indice': 88,
    },
    {
      'hora': 'Sábado',
      'icono': Icons.cloud,
      'condicion': 'Bueno',
      'indice': 75,
    },
    {
      'hora': 'Domingo',
      'icono': Icons.wb_sunny,
      'condicion': 'Excelente',
      'indice': 92,
    },
  ];

  List<Map<String, dynamic>> get _datosActuales {
    if (_opcionSeleccionada == 0) return _datosHoy;
    if (_opcionSeleccionada == 1) return _datosManana;
    return _datos7Dias;
  }

  @override
  Widget build(BuildContext context) {
    final listaActual = _datosActuales;

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Pronóstico por Horas',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Sandboarding en Huacachina',
                    style: TextStyle(fontSize: 14, color: AppColores.grisTexto),
                  ),
                ],
              ),
            ),

            // 2. Selector de pestañas (Hoy, Mañana, 7 días)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _botonToggle('Hoy', 0),
                    _botonToggle('Mañana', 1),
                    _botonToggle('7 días', 2),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Cabecera de la tabla
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Hora',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Condición',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Índice',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // 4. Lista de horas (AHORA DINÁMICA)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: listaActual.length,
                itemBuilder: (context, index) {
                  final data = listaActual[index];
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            // Hora
                            Expanded(
                              flex: 1,
                              child: Text(
                                data['hora'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            // Icono + Condición
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Icon(
                                    data['icono'],
                                    size: 20,
                                    color: AppColores.grisTexto,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    data['condicion'],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            // Índice
                            Expanded(
                              flex: 1,
                              child: Text(
                                data['indice'].toString(),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.black12,
                      ),
                    ],
                  );
                },
              ),
            ),

            // 5. Alerta inferior
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0), // Fondo naranja claro
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: AppColores.naranjaBoton),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Los vientos suelen intensificarse por la tarde en Huacachina.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para los botones del toggle
  Widget _botonToggle(String texto, int index) {
    final bool activo = _opcionSeleccionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _opcionSeleccionada = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: activo ? AppColores.marronOscuro : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                color: activo ? Colors.white : AppColores.grisTexto,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
