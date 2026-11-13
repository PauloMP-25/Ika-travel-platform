import 'package:flutter/material.dart';
import '../config/traducciones_scope.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../services/auth_service.dart';
import '../services/incidencias_service.dart';
import 'pantalla_login.dart';

/// Formulario para emisión de incidencias turísticas y denuncias de informalidad a DIRCETUR Ica (RF-05).
/// Requiere autenticación obligatoria del turista y consentimiento de geolocalización (RN-04).
class PantallaReporteIncidencia extends StatefulWidget {
  const PantallaReporteIncidencia({super.key});

  @override
  State<PantallaReporteIncidencia> createState() => _PantallaReporteIncidenciaState();
}

class _PantallaReporteIncidenciaState extends State<PantallaReporteIncidencia> {
  final _formKey = GlobalKey<FormState>();
  final IncidenciasService _incidenciasService = IncidenciasService();

  final TextEditingController _tituloCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();
  final TextEditingController _agenciaCtrl = TextEditingController();

  String _tipoSeleccionado = 'informal_service';
  bool _adjuntarUbicacion = true;
  bool _enviando = false;
  Position? _posicionActual;
  String? _mensajeResultado;
  bool? _envioExitoso;

  Map<String, String> _tiposIncidente(BuildContext context) => {
        'informal_service': context.tr('inc_informal'),
        'information_error': context.tr('inc_engano'),
        'route_obstruction': context.tr('inc_obstruccion'),
        'safety_hazard': context.tr('inc_riesgo'),
        'other': context.tr('inc_otro'),
      };

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionSiAutorizada();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _agenciaCtrl.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacionSiAutorizada() async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.whileInUse || permiso == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (mounted) {
          setState(() => _posicionActual = pos);
        }
      }
    } catch (_) {}
  }

  Future<void> _solicitarUbicacionManual() async {
    try {
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.whileInUse || permiso == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (mounted) {
          setState(() {
            _posicionActual = pos;
            _adjuntarUbicacion = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('rep_ubicacion_capturada')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _adjuntarUbicacion = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('rep_gps_no_concedido')),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('rep_gps_error')}: $e')),
        );
      }
    }
  }

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _mensajeResultado = null;
      _envioExitoso = null;
    });

    final res = await _incidenciasService.enviarReporte(
      tipoIncidente: _tipoSeleccionado,
      titulo: _tituloCtrl.text,
      descripcion: _descripcionCtrl.text,
      nombreAgencia: _agenciaCtrl.text,
      latitud: _adjuntarUbicacion ? _posicionActual?.latitude : null,
      longitud: _adjuntarUbicacion ? _posicionActual?.longitude : null,
    );

    if (mounted) {
      setState(() {
        _enviando = false;
        _envioExitoso = res.exitoso;
        _mensajeResultado = res.mensaje;
      });

      if (res.exitoso) {
        _tituloCtrl.clear();
        _descripcionCtrl.clear();
        _agenciaCtrl.clear();
      }
    }
  }

  Future<void> _llamar(String tel) async {
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSec = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final usuario = AuthService().usuarioActual;
    final esInvitado = usuario == null || usuario.esInvitado;

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorTexto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('rep_titulo'),
          style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: esInvitado
            ? _buildBarreraAutenticacion(colorTexto, colorTextoSec, colorTarjeta)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera institucional
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.campaign_rounded, color: Color(0xFFC62828), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('rep_dircetur_fisc'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFFB71C1C),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    context.tr('rep_ayuda'),
                                    style: TextStyle(fontSize: 11, color: Color(0xFFC62828)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tipo de incidencia
                      Text(
                        context.tr('rep_tipo'),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorTexto),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _tipoSeleccionado,
                            isExpanded: true,
                            dropdownColor: colorTarjeta,
                            style: TextStyle(color: colorTexto, fontSize: 13),
                            items: _tiposIncidente(context).entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(e.value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _tipoSeleccionado = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Título breve
                      Text(
                        context.tr('rep_titulo_breve'),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorTexto),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _tituloCtrl,
                        style: TextStyle(color: colorTexto, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: context.tr('rep_hint_titulo'),
                          hintStyle: TextStyle(color: colorTextoSec, fontSize: 13),
                          filled: true,
                          fillColor: colorTarjeta,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 3) {
                            return context.tr('rep_error_titulo');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nombre de la empresa / prestador
                      Text(
                        context.tr('rep_empresa'),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorTexto),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _agenciaCtrl,
                        style: TextStyle(color: colorTexto, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: context.tr('rep_hint_empresa'),
                          hintStyle: TextStyle(color: colorTextoSec, fontSize: 13),
                          filled: true,
                          fillColor: colorTarjeta,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Detalle de los hechos
                      Text(
                        context.tr('rep_descripcion'),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorTexto),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descripcionCtrl,
                        maxLines: 4,
                        style: TextStyle(color: colorTexto, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: context.tr('rep_hint_desc'),
                          hintStyle: TextStyle(color: colorTextoSec, fontSize: 13),
                          filled: true,
                          fillColor: colorTarjeta,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 10) {
                            return context.tr('rep_error_desc');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Ubicación GPS (RN-04)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _posicionActual != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                              color: _posicionActual != null ? Colors.green : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('ubicacion_incidente'),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorTexto),
                                  ),
                                  Text(
                                    _posicionActual != null
                                        ? 'GPS: ${_posicionActual!.latitude.toStringAsFixed(4)}, ${_posicionActual!.longitude.toStringAsFixed(4)}'
                                        : context.tr('rep_sin_coords'),
                                    style: TextStyle(fontSize: 11, color: colorTextoSec),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _solicitarUbicacionManual,
                              child: Text(_posicionActual == null ? context.tr('rep_obtener_gps') : 'Actualizar', style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mensaje de respuesta del servidor (Confirmación real)
                      if (_mensajeResultado != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _envioExitoso == true ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _envioExitoso == true ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _envioExitoso == true ? Icons.check_circle : Icons.error,
                                color: _envioExitoso == true ? Colors.green.shade800 : Colors.red.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _mensajeResultado!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: _envioExitoso == true ? Colors.green.shade900 : Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Botón de Envío
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC62828),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _enviando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _enviando ? context.tr('rep_enviando') : context.tr('rep_emitir'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          onPressed: _enviando ? null : _enviarReporte,
                        ),
                      ),

                      const SizedBox(height: 26),
                      // Números oficiales visibles de emergencia
                      Text(
                        context.tr('rep_canales'),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorTexto),
                      ),
                      const SizedBox(height: 10),
                      _contactoItem('POLTUR Ica (Policía de Turismo)', '056-224553', Icons.local_police, colorTarjeta, colorTexto),
                      _contactoItem('DIRCETUR Ica (Fiscalización)', '056-238710', Icons.account_balance, colorTarjeta, colorTexto),
                      _contactoItem('Central de Emergencias PNP', '105', Icons.shield, colorTarjeta, colorTexto),
                      _contactoItem('SAMU (Ambulancia)', '106', Icons.medical_services, colorTarjeta, colorTexto),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBarreraAutenticacion(Color colorTexto, Color colorTextoSec, Color colorTarjeta) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColores.naranjaBoton.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 54, color: AppColores.naranjaBoton),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('auth_requerida'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorTexto),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('auth_requerida_msg'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorTextoSec, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaBoton,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login),
              label: Text(context.tr('iniciar_o_registrar'), style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PantallaLogin(abrirComoModal: true)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactoItem(String nombre, String telefono, IconData icono, Color tarjeta, Color texto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tarjeta,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icono, color: AppColores.marronOscuro, size: 20),
        title: Text(nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: texto)),
        subtitle: Text(telefono, style: const TextStyle(fontSize: 11, color: AppColores.naranjaBoton)),
        trailing: IconButton(
          icon: const Icon(Icons.phone, size: 18, color: AppColores.naranjaBoton),
          onPressed: () => _llamar(telefono),
        ),
      ),
    );
  }
}
