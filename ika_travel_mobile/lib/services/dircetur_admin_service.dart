import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

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

  // --- REPORTES ---
  Future<List<dynamic>> listarReportes() async {
    final resp = await http.get(
      Uri.parse(ApiConfig.adminEmergencyReports),
      headers: ApiConfig.adminHeaders,
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    return [];
  }
}
