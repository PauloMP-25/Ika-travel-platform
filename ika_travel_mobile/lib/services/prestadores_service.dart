import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/prestador_servicio_modelo.dart';

class PrestadoresService {
  static final PrestadoresService _instancia = PrestadoresService._();
  factory PrestadoresService() => _instancia;
  PrestadoresService._();

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

      final uri = Uri.parse(ApiConfig.agencies)
          .replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = decoded is List
            ? decoded
            : (decoded['items'] ?? []);

        return items
            .map(
              (item) =>
                  PrestadorServicioModel.fromJson(item as Map<String, dynamic>),
            )
            .where((prestador) => prestador.esFormalValidado)
            .toList();
      }
    } catch (e) {
      debugPrint(
        '[PrestadoresService] Error consultando backend ($e), usando lista global.',
      );
    }

    // Fallback: Lista global compartida
    final locales = prestadoresGlobales.value
        .where((p) => p.esFormalValidado)
        .toList();

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return locales.where((p) {
        final coincideNombre = p.name.toLowerCase().contains(q);
        final coincideTour = p.tours.any(
          (t) =>
              t.name.toLowerCase().contains(q) ||
              t.description.toLowerCase().contains(q) ||
              (t.attractionName?.toLowerCase().contains(q) ?? false),
        );
        return coincideNombre || coincideTour;
      }).toList();
    }

    return locales;
  }

  Future<PrestadorServicioModel?> obtenerDetallePrestador(
    String agencyId,
  ) async {
    try {
      final uri = Uri.parse(ApiConfig.agencyDetail(agencyId));
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final prestador = PrestadorServicioModel.fromJson(decoded);
        if (prestador.esFormalValidado) return prestador;
        return null;
      }
    } catch (e) {
      debugPrint('[PrestadoresService] Error obteniendo detalle ($e)');
    }

    // Fallback: Lista global
    final local = prestadoresGlobales.value.firstWhere(
      (p) => p.id == agencyId && p.esFormalValidado,
      orElse: () =>
          const PrestadorServicioModel(id: '', name: '', isValidated: false),
    );

    return local.id.isNotEmpty ? local : null;
  }
}
