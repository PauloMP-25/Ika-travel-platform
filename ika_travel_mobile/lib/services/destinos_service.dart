import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../models/itinerario_modelo.dart';

/// Servicio para obtener los destinos y atractivos desde la base de datos (API)
/// con fallback a los destinos predefinidos locales si no hay conexión.
class DestinosService {
  static final DestinosService _instancia = DestinosService._();
  factory DestinosService() => _instancia;
  DestinosService._();

  List<PuntoItinerario>? _cacheDestinos;

  /// Obtiene la lista de atractivos turísticos desde la BD a través del endpoint /geo/nearby.
  /// Si el backend no está disponible o falla, devuelve [DestinosPredefinidos.lista].
  Future<List<PuntoItinerario>> obtenerDestinos({bool forzarRecarga = false}) async {
    if (!forzarRecarga && _cacheDestinos != null && _cacheDestinos!.isNotEmpty) {
      return _cacheDestinos!;
    }

    try {
      final url = Uri.parse(ApiConfig.geoNearby());
      final res = await http.get(url, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final items = data['items'] as List<dynamic>? ?? [];

        if (items.isNotEmpty) {
          final destinos = items.map((item) {
            final id = item['id']?.toString() ?? UniqueKey().toString();
            final nombre = item['name']?.toString() ?? 'Sin nombre';
            final distrito = item['district']?.toString() ?? 'Ica';
            final categorias = (item['categories'] as List<dynamic>?)?.join(', ') ?? '';
            final descripcion = categorias.isNotEmpty ? '$distrito — $categorias' : distrito;
            final lat = (item['latitude'] as num?)?.toDouble() ?? -14.0685;
            final lon = (item['longitude'] as num?)?.toDouble() ?? -75.7288;

            return PuntoItinerario(
              id: id,
              nombre: nombre,
              descripcion: descripcion,
              coordenadas: LatLng(lat, lon),
            );
          }).toList();

          _cacheDestinos = destinos;
          return destinos;
        }
      }
    } catch (e) {
      debugPrint('[DestinosService] No se pudo conectar a la API de destinos ($e), usando locales.');
    }

    return DestinosPredefinidos.lista;
  }
}
