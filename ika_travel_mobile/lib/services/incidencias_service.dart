import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

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
          mensaje: 'Reporte registrado formalmente ante DIRCETUR Ica (Estado: $status).',
          reportId: id,
          status: status,
        );
      } else if (response.statusCode == 401) {
        return const ResultadoReporteIncidencia(
          exitoso: false,
          mensaje: 'Tu sesión ha expirado. Inicia sesión nuevamente para enviar el reporte.',
        );
      } else {
        return ResultadoReporteIncidencia(
          exitoso: false,
          mensaje: 'El servidor no pudo procesar el reporte (Código: ${response.statusCode}).',
        );
      }
    } catch (e) {
      debugPrint('[IncidenciasService] Error al conectar con DIRCETUR: $e');
      // No simulamos confirmación si la API no respondió
      return ResultadoReporteIncidencia(
        exitoso: false,
        mensaje: 'No hubo conexión con la central de reportes de DIRCETUR ($e). Puedes comunicarte directamente al 056-238710 o a POLTUR al 056-224553.',
      );
    }
  }
}
