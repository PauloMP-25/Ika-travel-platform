import 'package:flutter/foundation.dart';

import '../models/itinerario_modelo.dart';
import '../models/lugar_modelo.dart';
import 'lugares_service.dart';

/// Destinos para el planificador de itinerarios.
///
/// No tiene lista propia: reutiliza el catálogo de [LugaresService] (base de
/// datos, con respaldo en los mocks) y lo traduce a [PuntoItinerario]. Así el
/// planificador ofrece exactamente los mismos lugares que la galería y el
/// mapa, con las mismas coordenadas.
class DestinosService {
  static final DestinosService _instancia = DestinosService._();
  factory DestinosService() => _instancia;
  DestinosService._();

  /// Duración de visita de respaldo, en minutos, si un lugar llegara sin tiempo.
  static const int _minutosVisitaPorDefecto = 60;

  List<PuntoItinerario>? _cache;

  Future<List<PuntoItinerario>> obtenerDestinos({
    bool forzarRecarga = false,
  }) async {
    if (!forzarRecarga && _cache != null && _cache!.isNotEmpty) return _cache!;

    final lugares = await LugaresService().obtenerLugares(
      forzarRecarga: forzarRecarga,
    );

    // Solo sirven los que tienen coordenadas: sin ellas no se puede trazar ruta.
    final puntos = lugares
        .where((l) => l.tieneCoordenadas)
        .map(_aPuntoItinerario)
        .toList();

    if (puntos.isEmpty) {
      debugPrint(
        '[DestinosService] Ningún lugar con coordenadas; uso los predefinidos.',
      );
      return DestinosPredefinidos.lista;
    }

    _cache = puntos;
    return puntos;
  }

  PuntoItinerario _aPuntoItinerario(LugarIca lugar) {
    final categorias = lugar.categorias.join(', ');
    return PuntoItinerario(
      id: lugar.id,
      nombre: lugar.nombre,
      descripcion: categorias.isNotEmpty
          ? '${lugar.distrito} — $categorias'
          : lugar.distrito,
      coordenadas: lugar.coordenadas!,
      tiempoVisitaMinutos: lugar.duracionVisitaMinutos > 0
          ? lugar.duracionVisitaMinutos
          : _minutosVisitaPorDefecto,
    );
  }

  void limpiarCache() => _cache = null;
}
