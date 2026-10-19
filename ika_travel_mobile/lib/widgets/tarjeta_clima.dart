import 'package:flutter/material.dart';
import '../config/tema.dart';
import '../services/alertas_service.dart';
import '../screens/pantalla_alertas.dart';
import '../screens/pantalla_seguimiento_destino.dart';

/// Tarjeta de Clima Inteligente y Monitoreo para Pantalla de Inicio
class TarjetaClima extends StatelessWidget {
  final String ciudad;
  final String temperatura;
  final String condicion;
  final String viento;
  final String uv;

  const TarjetaClima({
    super.key,
    this.ciudad = 'Ica & Huacachina',
    this.temperatura = '26°C',
    this.condicion = 'Soleado con viento térmico',
    this.viento = '22 km/h',
    this.uv = 'Muy Alto (8)',
  });

  @override
  Widget build(BuildContext context) {
    final alertasService = AlertasService();

    return ValueListenableBuilder(
      valueListenable: alertasService.alertasNotifier,
      builder: (context, alertas, _) {
        final alertasActivas = alertasService.alertasActivas;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Ubicación + Badge de Alertas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColores.naranjaBoton, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        ciudad,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ],
                  ),
                  if (alertasActivas.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PantallaAlertas(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF5350)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 14, color: Color(0xFFC62828)),
                            const SizedBox(width: 4),
                            Text(
                              '${alertasActivas.length} alertas',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Fila central: Temperatura y Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        temperatura,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                      Text(
                        condicion,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColores.grisTexto,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.wb_sunny,
                    size: 44,
                    color: AppColores.naranjaBoton,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 10),

              // Métricas rápidas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.air, size: 16, color: AppColores.grisTexto),
                      const SizedBox(width: 4),
                      Text(
                        'Viento: $viento',
                        style: const TextStyle(
                            fontSize: 12, color: AppColores.marronOscuro),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined,
                          size: 16, color: AppColores.grisTexto),
                      const SizedBox(width: 4),
                      Text(
                        'UV: $uv',
                        style: const TextStyle(
                            fontSize: 12, color: AppColores.marronOscuro),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaSeguimientoDestino(),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Text(
                          'Monitoreo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColores.naranjaBoton,
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16, color: AppColores.naranjaBoton),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
