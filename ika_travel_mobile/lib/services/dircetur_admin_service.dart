import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class DirceturAdminService {
  // --- ATRACTIVOS ---

  Future<List<dynamic>> listarAtractivos() async {
    final resp = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/catalog/attractions?page_size=50'),
      headers: ApiConfig.defaultHeaders,
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['items'] ?? data ?? [];
    }
    return [];
  }

  Future<bool> crearAtractivo(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/catalog/admin/attractions'),
      headers: ApiConfig.adminHeaders,
      body: jsonEncode(data),
    );
    return resp.statusCode == 201;
  }

  Future<bool> actualizarAtractivo(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/catalog/admin/attractions/$id'),
      headers: ApiConfig.adminHeaders,
      body: jsonEncode(data),
    );
    return resp.statusCode == 200;
  }

  Future<bool> eliminarAtractivo(String id) async {
    final resp = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/catalog/admin/attractions/$id'),
      headers: ApiConfig.adminHeaders,
    );
    return resp.statusCode == 204;
  }

  // --- AGENCIAS ---

  Future<List<dynamic>> listarAgencias() async {
    final resp = await http.get(
      Uri.parse(ApiConfig.agencies),
      headers: ApiConfig.defaultHeaders,
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    return [];
  }

  Future<bool> crearAgencia(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.adminAgencies),
      headers: ApiConfig.adminHeaders,
      body: jsonEncode(data),
    );
    return resp.statusCode == 201;
  }

  Future<bool> actualizarAgencia(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/catalog/admin/agencies/$id'),
      headers: ApiConfig.adminHeaders,
      body: jsonEncode(data),
    );
    return resp.statusCode == 200;
  }

  Future<bool> eliminarAgencia(String id) async {
    final resp = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/catalog/admin/agencies/$id'),
      headers: ApiConfig.adminHeaders,
    );
    return resp.statusCode == 204;
  }

  // --- REPORTES DE INCIDENCIA (DIRCETUR) ---

  /// Reportes de informalidad e incidencias enviados por los turistas.
  ///
  /// Este endpoint se protege con el JWT de un usuario con rol admin
  /// (`require_dircetur_admin` en el backend), no con `X-Admin-Key` como el
  /// resto del panel. Si se envía la clave de admin en vez del token, la API
  /// responde 401 y el panel aparece vacío.
  Future<List<dynamic>> listarReportes() async {
    final token = AuthService().usuarioActual?.token;
    if (token == null || token.isEmpty || token.startsWith('jwt_offline')) {
      debugPrint('[DirceturAdmin] Sin sesión válida para listar reportes.');
      return [];
    }

    try {
      final resp = await http
          .get(
            Uri.parse(ApiConfig.adminEmergencyReports),
            headers: {
              ...ApiConfig.defaultHeaders,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        return data is List ? data : [];
      }
      debugPrint('[DirceturAdmin] El listado de reportes respondió '
          '${resp.statusCode}.');
    } catch (e) {
      debugPrint('[DirceturAdmin] Error al listar reportes: $e');
    }
    return [];
  }

  /// Cambia el estado de un reporte desde el panel (recibido → en revisión →
  /// atendido). Devuelve true si el backend lo aceptó.
  Future<bool> actualizarEstadoReporte(String id, String nuevoEstado) async {
    final token = AuthService().usuarioActual?.token;
    if (token == null || token.isEmpty) return false;

    try {
      final resp = await http
          .patch(
            Uri.parse(ApiConfig.adminEmergencyReportDetail(id)),
            headers: {
              ...ApiConfig.defaultHeaders,
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'status': nuevoEstado}),
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('[DirceturAdmin] Error al actualizar el reporte: $e');
      return false;
    }
  }
}
