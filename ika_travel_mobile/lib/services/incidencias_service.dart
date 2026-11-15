import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'persistencia_service.dart';

class ResultadoReporteIncidencia {
  final bool exitoso;
  final String mensaje;
  final String? reportId;
  final String? status;

  const ResultadoReporteIncidencia({
    required this.exitoso,
    required this.mensaje,
    this.reportId,
    this.status,
  });
}

/// Servicio para enviar reportes de incidentes e informalidad a DIRCETUR Ica (RF-05).
class IncidenciasService {
  static final IncidenciasService _instancia = IncidenciasService._();
  factory IncidenciasService() => _instancia;
  IncidenciasService._();

  /// Envía un reporte formal a DIRCETUR a través de /api/v1/emergency/reports.
  /// Requiere autenticación del turista.
  Future<ResultadoReporteIncidencia> enviarReporte({
    required String tipoIncidente, // informal_service, information_error, route_obstruction, safety_hazard, other
    required String titulo,
    required String descripcion,
    String? nombreAgencia,
    double? latitud,
    double? longitud,
  }) async {
    final usuario = AuthService().usuarioActual;
    if (usuario == null || usuario.esInvitado) {
      return const ResultadoReporteIncidencia(
        exitoso: false,
        mensaje: 'Debes iniciar sesión con una cuenta registrada para emitir un reporte formal a DIRCETUR.',
      );
    }

    try {
      final token = usuario.token ?? '';
      final url = Uri.parse(ApiConfig.emergencyReports);
      final bodyMap = <String, dynamic>{
        'incident_type': tipoIncidente,
        'title': titulo.trim(),
        'description': descripcion.trim(),
        if (nombreAgencia != null && nombreAgencia.trim().isNotEmpty)
          'agency_name': nombreAgencia.trim(),
        if (latitud != null) 'latitude': latitud,
        if (longitud != null) 'longitude': longitud,
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Idempotency-Key': 'rep_${DateTime.now().millisecondsSinceEpoch}_${usuario.id}',
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(bodyMap))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final id = data['id']?.toString() ?? 'ok';
        final status = data['status']?.toString() ?? 'received';
        return ResultadoReporteIncidencia(
          exitoso: true,
          mensaje: 'Reporte registrado ante DIRCETUR Ica. Ya aparece en el '
              'panel de fiscalización.',
          reportId: id,
          status: status,
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ResultadoReporteIncidencia(
          exitoso: false,
          mensaje: 'Tu sesión expiró. Inicia sesión otra vez para enviar el '
              'reporte.',
        );
      }

      // Cualquier otra respuesta es un problema del servidor, no del usuario:
      // guardamos el reporte en el teléfono para no perderlo.
      debugPrint('[IncidenciasService] La central respondió '
          '${response.statusCode}: ${response.body}');
      await _guardarPendiente(bodyMap);
      return const ResultadoReporteIncidencia(
        exitoso: false,
        mensaje: _mensajeGuardado,
      );
    } catch (e) {
      debugPrint('[IncidenciasService] Error al conectar con DIRCETUR: $e');
      await _guardarPendiente({
        'incident_type': tipoIncidente,
        'title': titulo.trim(),
        'description': descripcion.trim(),
        if (nombreAgencia != null && nombreAgencia.trim().isNotEmpty)
          'agency_name': nombreAgencia.trim(),
        if (latitud != null) 'latitude': latitud,
        if (longitud != null) 'longitude': longitud,
      });
      return const ResultadoReporteIncidencia(
        exitoso: false,
        mensaje: _mensajeGuardado,
      );
    }
  }

  /// Mensaje único para cuando el reporte no llegó pero quedó a salvo.
  /// Sin códigos de error: al turista no le dicen nada y asustan.
  static const String _mensajeGuardado =
      'La central de DIRCETUR no respondió. Tu reporte quedó guardado en el '
      'teléfono y se enviará solo en cuanto vuelva el servicio. Si es urgente, '
      'llama a DIRCETUR al 056-238710 o a POLTUR al 056-224553.';

  static const String _claveP = 'reportes_pendientes';

  Future<List<Map<String, dynamic>>> _leerPendientes() async {
    final guardado = await PersistenciaService().leerJson(_claveP);
    final lista = guardado?['items'];
    if (lista is! List) return [];
    return lista.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> _escribirPendientes(List<Map<String, dynamic>> items) async {
    await PersistenciaService().guardarJson(_claveP, {'items': items});
  }

  Future<void> _guardarPendiente(Map<String, dynamic> cuerpo) async {
    final pendientes = await _leerPendientes();
    pendientes.add({
      ...cuerpo,
      'guardado_en': DateTime.now().toIso8601String(),
    });
    await _escribirPendientes(pendientes);
    debugPrint('[IncidenciasService] Reporte guardado como pendiente '
        '(${pendientes.length} en cola).');
  }

  /// Cuántos reportes esperan a que vuelva el servidor.
  Future<int> contarPendientes() async => (await _leerPendientes()).length;

  /// Reintenta enviar los reportes que quedaron guardados. Devuelve cuántos
  /// se enviaron. Es seguro llamarla cada vez que se abre la pantalla: si no
  /// hay pendientes o no hay sesión, no hace nada.
  Future<int> reintentarPendientes() async {
    final pendientes = await _leerPendientes();
    if (pendientes.isEmpty) return 0;

    final usuario = AuthService().usuarioActual;
    final token = usuario?.token ?? '';
    if (usuario == null || usuario.esInvitado || token.isEmpty) return 0;

    final quedan = <Map<String, dynamic>>[];
    var enviados = 0;

    for (final pendiente in pendientes) {
      final cuerpo = Map<String, dynamic>.from(pendiente)
        ..remove('guardado_en');
      try {
        final response = await http
            .post(
              Uri.parse(ApiConfig.emergencyReports),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'ngrok-skip-browser-warning': 'true',
                'Authorization': 'Bearer $token',
                'Idempotency-Key':
                    'rep_${pendiente['guardado_en']}_${usuario.id}',
              },
              body: jsonEncode(cuerpo),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          enviados++;
          continue;
        }
      } catch (e) {
        debugPrint('[IncidenciasService] Sigue sin poder enviarse: $e');
      }
      quedan.add(pendiente);
    }

    await _escribirPendientes(quedan);
    if (enviados > 0) {
      debugPrint('[IncidenciasService] $enviados reportes pendientes '
          'enviados a DIRCETUR.');
    }
    return enviados;
  }

  /// Reportes que el propio usuario ya envió, para que confirme que llegaron.
  Future<List<Map<String, dynamic>>> misReportes() async {
    final token = AuthService().usuarioActual?.token ?? '';
    if (token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.myEmergencyReports),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
        }
      }
    } catch (e) {
      debugPrint('[IncidenciasService] No se pudo listar mis reportes: $e');
    }
    return [];
  }
}
