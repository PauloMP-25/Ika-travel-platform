import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/favoritos_manager.dart';
import 'pantalla_configurar_alertas.dart';

class PantallaAlertas extends StatefulWidget {
  const PantallaAlertas({super.key});

  @override
  State<PantallaAlertas> createState() => _PantallaAlertasState();
}

class _PantallaAlertasState extends State<PantallaAlertas> {
  int _opcionSeleccionada = 0;

  // 1. Alertas activas por actividad (simulando backend)
  final Map<String, List<Map<String, dynamic>>> _alertasPorActividad = {
    'Sandboarding\nen Huacachina': [
      {
        'titulo': 'Viento fuerte en Huacachina',
        'fecha': 'Hoy, 16:00',
        'descripcion': 'Vientos de 25 km/h. Ideal para sandboarding.',
        'icono': Icons.warning_amber_rounded,
        'colorIcono': Colors.orange,
      },
    ],
    'Islas Ballestas': [
      {
        'titulo': 'Mar picado en Paracas',
        'fecha': 'Hoy, 14:00',
        'descripcion': 'Oleaje moderado. Lleva ropa impermeable.',
        'icono': Icons.water,
        'colorIcono': Colors.blue,
      },
    ],
    'Reserva Nacional\nde Paracas': [
      {
        'titulo': 'Sol intenso en la Reserva',
        'fecha': 'Mañana',
        'descripcion': 'UV Alto. Usa protector solar y gorra.',
        'icono': Icons.wb_sunny,
        'colorIcono': Colors.orange,
      },
    ],
    'Viñedos y bodegas': [
      {
        'titulo': 'Clima agradable en viñedos',
        'fecha': 'Hoy, 12:00',
        'descripcion': 'Temperatura 24°C. Perfecto para un tour.',
        'icono': Icons.info_outline,
        'colorIcono': AppColores.marronOscuro,
      },
    ],
  };

  // 2. Historial de alertas (datos fijos de ejemplo)
  final List<Map<String, dynamic>> _historial = [
    {
      'titulo': 'Viento fuerte en Paracas',
      'fecha': 'Ayer, 15:00',
      'descripcion': 'Se registraron ráfagas de 30 km/h.',
      'icono': Icons.history,
      'colorIcono': Colors.grey,
    },
    {
      'titulo': 'Cielo despejado en Ica',
      'fecha': 'Hace 3 días',
      'descripcion': 'Condiciones perfectas para turismo.',
      'icono': Icons.wb_sunny,
      'colorIcono': Colors.orange,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColores.marronOscuro,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Alertas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColores.marronOscuro,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaConfigurarAlertas(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Selector de pestañas
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
                    _botonToggle('Alertas', 0),
                    _botonToggle('Historial', 1),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Contenido según la pestaña seleccionada
            Expanded(
              child: _opcionSeleccionada == 0
                  ? _buildAlertasActivas()
                  : _buildHistorial(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertasActivas() {
    return ValueListenableBuilder(
      valueListenable: listaFavoritos,
      builder: (context, favoritos, child) {
        if (favoritos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 60,
                  color: Colors.grey,
                ),
                SizedBox(height: 10),
                Text(
                  'Agrega actividades a favoritos\npara recibir sus alertas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColores.grisTexto, fontSize: 16),
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> alertasAMostrar = [];
        for (var fav in favoritos) {
          final titulo = fav['titulo'];
          if (_alertasPorActividad.containsKey(titulo)) {
            alertasAMostrar.addAll(_alertasPorActividad[titulo]!);
          }
        }

        if (alertasAMostrar.isEmpty) {
          return const Center(
            child: Text(
              'No hay alertas activas para tus favoritos.',
              style: TextStyle(color: AppColores.grisTexto, fontSize: 16),
            ),
          );
        }

        return _construirLista(alertasAMostrar);
      },
    );
  }

  Widget _buildHistorial() {
    return _construirLista(_historial);
  }

  Widget _construirLista(List<Map<String, dynamic>> lista) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final alerta = lista[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(alerta['icono'], color: alerta['colorIcono'], size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alerta['titulo'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                    Text(
                      alerta['fecha'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.grisTexto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alerta['descripcion'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
