import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../config/favoritos_manager.dart';

class PantallaAlertas extends StatefulWidget {
  const PantallaAlertas({super.key});

  @override
  State<PantallaAlertas> createState() => _PantallaAlertasState();
}

class _PantallaAlertasState extends State<PantallaAlertas> {
  int _opcionSeleccionada = 0;

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
    final colorTexto = TemaApp.texto(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorTexto, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Alertas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: colorTexto,
                      size: 28,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: colorTarjeta,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _botonToggle('Alertas', 0, colorTexto),
                    _botonToggle('Historial', 1, colorTexto),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
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
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return ValueListenableBuilder(
      valueListenable: listaFavoritos,
      builder: (context, favoritos, child) {
        if (favoritos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  size: 60,
                  color: Colors.grey,
                ),
                const SizedBox(height: 10),
                Text(
                  'Agrega actividades a favoritos\npara recibir sus alertas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorTextoSecundario, fontSize: 16),
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
          return Center(
            child: Text(
              'No hay alertas activas para tus favoritos.',
              style: TextStyle(color: colorTextoSecundario, fontSize: 16),
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
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final alerta = lista[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorTarjeta,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorTexto,
                      ),
                    ),
                    Text(
                      alerta['fecha'],
                      style: TextStyle(
                        fontSize: 12,
                        color: colorTextoSecundario,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alerta['descripcion'],
                      style: TextStyle(fontSize: 13, color: colorTexto),
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

  Widget _botonToggle(String texto, int index, Color colorTexto) {
    final bool activo = _opcionSeleccionada == index;
    final colorTextoSecundario = TemaApp.textoSecundario(context);

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
                color: activo ? Colors.white : colorTextoSecundario,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
