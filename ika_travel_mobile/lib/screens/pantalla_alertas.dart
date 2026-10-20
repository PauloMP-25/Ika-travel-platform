import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/alerta_modelo.dart';
import '../models/alternativa_modelo.dart';
import '../services/alertas_service.dart';
import '../services/recomendador_service.dart';
import 'pantalla_configurar_alertas.dart';
import 'pantalla_detalle_alerta.dart';
import 'pantalla_detalle_alternativa.dart';
import 'pantalla_seguimiento_destino.dart';

class PantallaAlertas extends StatefulWidget {
  const PantallaAlertas({super.key});

  @override
  State<PantallaAlertas> createState() => _PantallaAlertasState();
}

class _PantallaAlertasState extends State<PantallaAlertas> {
  int _opcionSeleccionada =
      0; // 0 = Alertas activas, 1 = Alternativas, 2 = Historial
  final AlertasService _alertasService = AlertasService();
  final RecomendadorService _recomendadorService = RecomendadorService();

  String _formatearFechaHora(DateTime dt) {
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    final hoy = DateTime.now();
    if (dt.day == hoy.day && dt.month == hoy.month && dt.year == hoy.year) {
      return 'Hoy, $hora:$minuto';
    } else if (hoy.difference(dt).inDays <= 1) {
      return 'Ayer, $hora:$minuto';
    } else {
      return 'Hace ${hoy.difference(dt).inDays} días';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      body: SafeArea(
        child: Column(
          children: [
            // 1. AppBar con flecha atrás, título y botones de acción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColores.marronOscuro,
                      size: 26,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Alertas Inteligentes',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Seguimiento de destinos',
                        icon: const Icon(
                          Icons.timeline,
                          color: AppColores.naranjaBoton,
                          size: 24,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PantallaSeguimientoDestino(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Configuración y permisos',
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: AppColores.marronOscuro,
                          size: 24,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PantallaConfigurarAlertas(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. 👇 BANNER DE SIMULACIÓN (comentado para ocultarlo en producción)
            // Si quieres usarlo para la demo, descomenta este bloque.
            /*
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on, color: Color(0xFFF57F17), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Simulación de alerta automática en tiempo real:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColores.marronOscuro,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        backgroundColor: AppColores.naranjaBoton,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final nueva = _alertasService.simularDeteccionEnVivo();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '¡Alerta automática generada para ${nueva.destino}!\n${nueva.titulo}',
                            ),
                            backgroundColor: const Color(0xFFC62828),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      child: const Text('Simular', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            */

            // 3. Selector de 3 pestañas: Alertas Activas, Alternativas, Historial
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _botonToggle('Alertas', 0),
                    _botonToggle('Alternativas', 1),
                    _botonToggle('Historial', 2),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 4. Contenido según la pestaña seleccionada
            Expanded(
              child: _opcionSeleccionada == 1
                  ? _buildVistaAlternativas()
                  : _buildVistaAlertasOHistorial(),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista de Alertas o Historial
  Widget _buildVistaAlertasOHistorial() {
    return ValueListenableBuilder<List<AlertaClima>>(
      valueListenable: _alertasService.alertasNotifier,
      builder: (context, todasAlertas, _) {
        final listaAMostrar = _opcionSeleccionada == 0
            ? _alertasService.alertasActivas
            : _alertasService.historialAlertas;

        // 👇 Mensaje cuando no hay alertas (backend devolvió [])
        if (listaAMostrar.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _opcionSeleccionada == 0
                      ? Icons.check_circle_outline
                      : Icons.history_toggle_off,
                  size: 60,
                  color: Colors.green.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  _opcionSeleccionada == 0
                      ? '✅ ¡Todo tranquilo en Ica!\nNo hay alertas climáticas activas.'
                      : 'No hay historial de alertas registrado.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColores.grisTexto,
                    fontSize: 15,
                  ),
                ),
                if (_opcionSeleccionada == 0) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Las alertas aparecerán aquí cuando el clima empeore.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            // Banner informativo en caso de condiciones desfavorables
            if (_opcionSeleccionada == 0 &&
                listaAMostrar.any(
                  (a) =>
                      a.nivelRiesgo == NivelRiesgo.alto ||
                      a.nivelRiesgo == NivelRiesgo.critico,
                )) ...[
              GestureDetector(
                onTap: () {
                  setState(() => _opcionSeleccionada = 1);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.alt_route, color: Color(0xFFE65100), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hay condiciones desfavorables. Toca aquí para ver alternativas recomendadas.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFFE65100),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            ...listaAMostrar.map((alerta) => _buildItemAlerta(context, alerta)),
          ],
        );
      },
    );
  }

  /// Vista de Alternativas Recomendadas
  Widget _buildVistaAlternativas() {
    final alternativas = _recomendadorService.obtenerAlternativasGenerales();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF2E7D32), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alternativas sugeridas ante vientos, oleaje o radiación extrema en los destinos de Ica. Toca cualquier tarjeta para ver su detalle completo.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1B5E20),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        ...alternativas.map(
          (alt) => _buildTarjetaAlternativaResumida(context, alt),
        ),
      ],
    );
  }

  /// Tarjeta de Alternativa
  Widget _buildTarjetaAlternativaResumida(
    BuildContext context,
    AlternativaRecomendada alt,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PantallaDetalleAlternativa(alternativa: alt),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 125,
                      width: double.infinity,
                      child: Image.asset(
                        alt.imagen,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 125,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColores.naranjaBoton,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          alt.tipoAlternativa.etiqueta,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 14,
                      right: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alt.tituloActividad,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            alt.destino,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.recommend,
                          color: AppColores.naranjaBoton,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alt.motivoRecomendacion,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.marronOscuro,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (alt.mejorHorarioSugerido != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Color(0xFFF57F17),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Horario sugerido: ${alt.mejorHorarioSugerido}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Ver detalle completo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColores.marronOscuro,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: AppColores.marronOscuro,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemAlerta(BuildContext context, AlertaClima alerta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PantallaDetalleAlerta(alerta: alerta),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: alerta.nivelRiesgo.colorFondo,
                      child: Icon(
                        alerta.nivelRiesgo.icono,
                        color: alerta.nivelRiesgo.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColores.arenaFondo,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  alerta.destino,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColores.marronOscuro,
                                  ),
                                ),
                              ),
                              Text(
                                _formatearFechaHora(alerta.fechaHora),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColores.grisTexto,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alerta.titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColores.marronOscuro,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alerta.actividad.replaceAll('\n', ' '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.naranjaBoton,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  alerta.motivoCambio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColores.marronOscuro,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: alerta.nivelRiesgo.colorFondo,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        alerta.nivelRiesgo.etiqueta,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: alerta.nivelRiesgo.color,
                        ),
                      ),
                    ),
                    const Row(
                      children: [
                        Text(
                          '¿Por qué cambió?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColores.naranjaBoton,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 11,
                          color: AppColores.naranjaBoton,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
