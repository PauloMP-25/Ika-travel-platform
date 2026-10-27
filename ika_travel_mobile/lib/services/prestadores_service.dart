import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/prestador_servicio_modelo.dart';

/// Servicio para buscar y consultar agencias y prestadores turísticos formalizados.
/// Implementa estrictamente la regla RN-01:
/// Exclusivamente visibiliza prestadores cuyo estado sea Empadronado y Validado por DIRCETUR.
class PrestadoresService {
  static final PrestadoresService _instancia = PrestadoresService._();
  factory PrestadoresService() => _instancia;
  PrestadoresService._();

  /// Obtiene el listado de prestadores formalizados aplicando filtros de búsqueda.
  /// Aplica la regla RN-01: descarta cualquier prestador que no esté explícitamente validado.
  Future<List<PrestadorServicioModel>> buscarPrestadores({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (query != null && query.trim().isNotEmpty) {
        queryParams['query'] = query.trim();
      }

      final uri = Uri.parse(ApiConfig.agencies).replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = decoded is List ? decoded : (decoded['items'] ?? []);

        final prestadores = items
            .map((item) => PrestadorServicioModel.fromJson(item as Map<String, dynamic>))
            // REGLA RN-01: Si el backend no envía is_validated == true, no se asume validado
            .where((prestador) => prestador.esFormalValidado)
            .toList();

        return prestadores;
      }
    } catch (e) {
      debugPrint('[PrestadoresService] Error consultando agencias en backend ($e), usando locales certificados.');
    }

    // Fallback con datos verificados de DIRCETUR en caso de modo offline
    final locales = PrestadorServicioModel.prestadoresVerificadosLocales
        .where((p) => p.esFormalValidado)
        .toList();

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return locales.where((p) {
        final coincideNombre = p.name.toLowerCase().contains(q);
        final coincideTour = p.tours.any((t) =>
            t.name.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q) ||
            (t.attractionName?.toLowerCase().contains(q) ?? false));
        return coincideNombre || coincideTour;
      }).toList();
    }

    return locales;
  }

  /// Consulta el detalle de un prestador formal con sus tours homologados.
  Future<PrestadorServicioModel?> obtenerDetallePrestador(String agencyId) async {
    try {
      final uri = Uri.parse(ApiConfig.agencyDetail(agencyId));
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final prestador = PrestadorServicioModel.fromJson(decoded);

        // REGLA RN-01: Si no está validado por DIRCETUR, no se devuelve
        if (prestador.esFormalValidado) {
          return prestador;
        }
        return null;
      }
    } catch (e) {
      debugPrint('[PrestadoresService] Error obteniendo detalle de agencia ($e)');
    }

    // Buscar en caché local verificada
    final local = PrestadorServicioModel.prestadoresVerificadosLocales.firstWhere(
      (p) => p.id == agencyId && p.esFormalValidado,
      orElse: () => const PrestadorServicioModel(id: '', name: '', isValidated: false),
    );

    return local.id.isNotEmpty ? local : null;
  }
}
