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
  final Map<String, dynamic> _datosHoy = {
    'tempActual': '26°C',
    'condicion': 'Soleado',
    'tempMax': '27°C',
    'tempMin': '16°C',
    'iconoPrincipal': Icons.wb_sunny,
    'viento': '12 km/h',
    'humedad': '48%',
    'lluvia': '8%',
    'uv': 'Alto',
    'porHoras': [
      {'hora': '08:00', 'icono': Icons.wb_sunny, 'grados': '20°'},
      {'hora': '11:00', 'icono': Icons.wb_sunny, 'grados': '25°'},
      {'hora': '14:00', 'icono': Icons.wb_cloudy, 'grados': '25°'},
      {'hora': '17:00', 'icono': Icons.air, 'grados': '22°'},
      {'hora': '20:00', 'icono': Icons.nightlight_round, 'grados': '19°'},
    ],
  };

  // Datos de MAÑANA
  final Map<String, dynamic> _datosManana = {
    'tempActual': '22°C',
    'condicion': 'Parcialmente nublado',
    'tempMax': '24°C',
    'tempMin': '14°C',
    'iconoPrincipal': Icons.wb_cloudy,
    'viento': '20 km/h',
    'humedad': '60%',
    'lluvia': '15%',
    'uv': 'Moderado',
    'porHoras': [
      {'hora': '08:00', 'icono': Icons.cloud, 'grados': '16°'},
      {'hora': '11:00', 'icono': Icons.wb_cloudy, 'grados': '20°'},
      {'hora': '14:00', 'icono': Icons.wb_sunny, 'grados': '23°'},
      {'hora': '17:00', 'icono': Icons.cloud, 'grados': '18°'},
      {'hora': '20:00', 'icono': Icons.nightlight_round, 'grados': '15°'},
    ],
  };

  final Map<String, dynamic> _datos7Dias = {
    'tempActual': '24°C',
    'condicion': 'Variable',
    'tempMax': '27°C',
    'tempMin': '15°C',
    'iconoPrincipal': Icons.wb_cloudy,
    'viento': '15 km/h',
    'humedad': '55%',
    'lluvia': '10%',
    'uv': 'Moderado',
    'porHoras': [
      // Usamos la lista horizontal para mostrar los días de la semana
      {'hora': 'Lunes', 'icono': Icons.wb_sunny, 'grados': '27°'},
      {'hora': 'Martes', 'icono': Icons.wb_cloudy, 'grados': '25°'},
      {'hora': 'Miércoles', 'icono': Icons.wb_sunny, 'grados': '28°'},
      {'hora': 'Jueves', 'icono': Icons.air, 'grados': '22°'},
      {'hora': 'Viernes', 'icono': Icons.cloud, 'grados': '21°'},
      {'hora': 'Sábado', 'icono': Icons.wb_sunny, 'grados': '26°'},
      {'hora': 'Domingo', 'icono': Icons.wb_sunny, 'grados': '29°'},
    ],
  };

  Map<String, dynamic> get _datosActuales {
    if (_opcionSeleccionada == 0) return _datosHoy;
    if (_opcionSeleccionada == 1) return _datosManana;
    return _datos7Dias;
  }

  @override
  Widget build(BuildContext context) {
    final data = _datosActuales; // Obtenemos los datos actuales

    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                children: const [
                  Text(
                    'Pronóstico general',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  Text(
                    'Ica',
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

            // 3. Tarjeta principal del clima (DINÁMICA)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          data['iconoPrincipal'],
                          size: 50,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['tempActual'],
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColores.marronOscuro,
                              ),
                            ),
                            Text(
                              data['condicion'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColores.grisTexto,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Máx. ${data['tempMax']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColores.grisTexto,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mín. ${data['tempMin']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColores.grisTexto,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // 4. Fila de 4 íconos (DINÁMICA)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniFactor(
                      icono: Icons.air,
                      valor: data['viento'],
                      etiqueta: 'Viento',
                    ),
                    _MiniFactor(
                      icono: Icons.water_drop,
                      valor: data['humedad'],
                      etiqueta: 'Humedad',
                    ),
                    _MiniFactor(
                      icono: Icons.water_drop_outlined,
                      valor: data['lluvia'],
                      etiqueta: 'Lluvia',
                    ),
                    _MiniFactor(
                      icono: Icons.wb_sunny,
                      valor: data['uv'],
                      etiqueta: 'UV',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // 5. Sección "Por horas" (DINÁMICA)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _opcionSeleccionada == 2 ? 'Próximos días' : 'Por horas',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (data['porHoras'] as List).length,
                        itemBuilder: (context, index) {
                          final item = data['porHoras'][index];
                          return _HoraItem(
                            hora: item['hora'],
                            icono: item['icono'],
                            grados: item['grados'],
                          );
                        },
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

class _MiniFactor extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const _MiniFactor({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: AppColores.grisTexto, size: 22),
        const SizedBox(height: 5),
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 10, color: AppColores.grisTexto),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColores.marronOscuro,
          ),
        ),
      ],
    );
  }
}

class _HoraItem extends StatelessWidget {
  final String hora;
  final IconData icono;
  final String grados;

  const _HoraItem({
    required this.hora,
    required this.icono,
    required this.grados,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 25),
      child: Column(
        children: [
          Text(
            hora,
            style: const TextStyle(fontSize: 12, color: AppColores.grisTexto),
          ),
          const SizedBox(height: 8),
          Icon(icono, color: AppColores.marronOscuro, size: 20),
          const SizedBox(height: 8),
          Text(
            grados,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColores.marronOscuro,
            ),
          ),
        ],
      ),
    );
  }
}
