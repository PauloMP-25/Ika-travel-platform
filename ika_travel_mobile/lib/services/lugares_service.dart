import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../data/lugares_mock.dart';
import '../models/lugar_modelo.dart';

/// Puerta de entrada **única** del frontend al catálogo de lugares.
///
/// Antes había cinco listas de lugares distintas (el mapa, la galería, el
/// planificador y dos servicios más), cada una con nombres y coordenadas
/// propias; por eso el mapa y la galería no coincidían. Ahora todas las
/// pantallas piden los lugares aquí.
///
/// Orden de prioridad de los datos:
/// 1. **Base de datos** — `GET /catalog/attractions` da qué lugares existen
///    (nombre, distrito, categorías, portada) y `GET /geo/nearby` aporta las
///    coordenadas, que el listado paginado todavía no devuelve.
/// 2. **Detalle de la BD** — `GET /catalog/attractions/{id}` completa
///    descripción, imágenes y coordenadas de un lugar concreto.
/// 3. **Mocks locales** ([LugaresMock]) — se usan si la API falla, si devuelve
///    una lista vacía, o para rellenar campos que la API aún no entrega
///    (coordenadas e imágenes reales). Así la app **nunca** se ve vacía.
class LugaresService {
  static final LugaresService _instancia = LugaresService._();
  factory LugaresService() => _instancia;
  LugaresService._();

  static const Duration _timeout = Duration(seconds: 8);

  /// Centro de Ica: origen de la consulta de coordenadas a `/geo/nearby`.
  static const double _latIca = -14.0685;
  static const double _lonIca = -75.7288;

  List<LugarIca>? _cacheLugares;
  List<String>? _cacheCategorias;
  final Map<String, LugarIca> _cacheDetalles = {};

  /// `true` si lo último que se entregó salió de los mocks y no de la BD.
  /// Las pantallas lo usan para mostrar el aviso de "modo sin conexión".
  bool get usandoMocks => _usandoMocks;
  bool _usandoMocks = false;

  /// Lista de lugares para la galería y el mapa. Siempre devuelve algo.
  Future<List<LugarIca>> obtenerLugares({bool forzarRecarga = false}) async {
    if (!forzarRecarga && _cacheLugares != null) return _cacheLugares!;

    try {
      final listado = await _pedirListado();

      if (listado.isNotEmpty) {
        final coordenadas = await _pedirCoordenadas();
        final completos = [
          for (final lugar in listado) _completarConMock(lugar, coordenadas),
        ];
        _usandoMocks = false;
        _cacheLugares = completos;
        debugPrint(
          '[LugaresService] ${completos.length} lugares desde la BD '
          '(${completos.where((l) => l.tieneCoordenadas).length} con '
          'coordenadas).',
        );
        return completos;
      }

      debugPrint(
        '[LugaresService] La BD devolvió una lista vacía; uso los mocks.',
      );
    } catch (e) {
      debugPrint('[LugaresService] Sin conexión con la BD ($e); uso los mocks.');
    }

    _usandoMocks = true;
    _cacheLugares = LugaresMock.lugares;
    return _cacheLugares!;
  }

  /// Detalle completo de un lugar (descripción, imágenes y coordenadas).
  ///
  /// Si el id no es de la BD (un mock) o la petición falla, devuelve lo mejor
  /// que tenga a mano: el mock equivalente o el lugar ya cacheado.
  Future<LugarIca> obtenerDetalle(LugarIca lugarBase) async {
    final cacheado = _cacheDetalles[lugarBase.id];
    if (cacheado != null) return cacheado;

    // Los ids de mock no existen en la BD: no hay nada que pedir.
    if (lugarBase.esMock || lugarBase.id.isEmpty) {
      return _conRespaldoDeMock(lugarBase);
    }

    try {
      final url = Uri.parse(ApiConfig.attractionDetail(lugarBase.id));
      final res = await http
          .get(url, headers: ApiConfig.defaultHeaders)
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes));
        if (json is Map<String, dynamic>) {
          final detalle = _conRespaldoDeMock(LugarIca.deDetalle(json));
          _cacheDetalles[lugarBase.id] = detalle;
          return detalle;
        }
      }
      debugPrint(
        '[LugaresService] Detalle ${lugarBase.id}: HTTP ${res.statusCode}.',
      );
    } catch (e) {
      debugPrint('[LugaresService] No se pudo cargar el detalle ($e).');
    }

    return _conRespaldoDeMock(lugarBase);
  }

  /// Categorías para los filtros, tomadas de `category` en la BD.
  Future<List<String>> obtenerCategorias({bool forzarRecarga = false}) async {
    if (!forzarRecarga && _cacheCategorias != null) return _cacheCategorias!;

    try {
      final res = await http
          .get(Uri.parse(ApiConfig.categories), headers: ApiConfig.defaultHeaders)
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is List && data.isNotEmpty) {
          final nombres = data
              .map((c) => (c is Map ? c['name']?.toString() : c.toString()) ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
          if (nombres.isNotEmpty) {
            _cacheCategorias = nombres;
            return nombres;
          }
        }
      }
    } catch (e) {
      debugPrint('[LugaresService] Categorías desde mocks ($e).');
    }

    _cacheCategorias = LugaresMock.categorias;
    return _cacheCategorias!;
  }

  /// Busca un lugar ya cargado por su id (sin ir a la red).
  LugarIca? lugarEnCache(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final lugar in _cacheLugares ?? const <LugarIca>[]) {
      if (lugar.id == id) return lugar;
    }
    return LugaresMock.porId(id);
  }

  /// Filtra por categoría y texto libre. Lo comparten galería y mapa para que
  /// ambos respondan igual a los mismos filtros.
  List<LugarIca> filtrar(
    List<LugarIca> lugares, {
    String? categoria,
    String texto = '',
  }) {
    final hayCategoria =
        categoria != null && categoria.isNotEmpty && categoria != 'Todas';
    return lugares.where((lugar) {
      if (hayCategoria && !lugar.esDeCategoria(categoria)) return false;
      return lugar.coincideCon(texto);
    }).toList();
  }

  void limpiarCache() {
    _cacheLugares = null;
    _cacheCategorias = null;
    _cacheDetalles.clear();
  }

  // ------------------------------------------------------------------
  // Internos
  // ------------------------------------------------------------------

  /// `GET /catalog/attractions` (qué lugares existen en la BD).
  Future<List<LugarIca>> _pedirListado() async {
    final url = Uri.parse('${ApiConfig.attractions}?page_size=50');
    final res = await http
        .get(url, headers: ApiConfig.defaultHeaders)
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} en el listado de atractivos');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final items = data is List
        ? data
        : (data['items'] as List<dynamic>? ?? const []);

    return items
        .whereType<Map<String, dynamic>>()
        .map(LugarIca.deListado)
        .where((l) => l.id.isNotEmpty)
        .toList();
  }

  /// `GET /geo/nearby` → coordenadas de la BD indexadas por id de atractivo.
  ///
  /// El listado paginado no trae latitud/longitud (ver pendientes del
  /// backend), así que esta es la vía para obtenerlas en una sola petición.
  /// Si falla, no es fatal: las coordenadas se completan con los mocks.
  Future<Map<String, LugarIca>> _pedirCoordenadas() async {
    try {
      final url = Uri.parse(
        ApiConfig.geoNearby(lat: _latIca, lon: _lonIca),
      );
      final res = await http
          .get(url, headers: ApiConfig.defaultHeaders)
          .timeout(_timeout);

      if (res.statusCode != 200) return const {};

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final items = data['items'] as List<dynamic>? ?? const [];
      final mapa = <String, LugarIca>{};
      for (final item in items.whereType<Map<String, dynamic>>()) {
        final lugar = LugarIca.deCercanos(item);
        if (lugar.id.isNotEmpty) mapa[lugar.id] = lugar;
      }
      return mapa;
    } catch (e) {
      debugPrint('[LugaresService] /geo/nearby no respondió ($e).');
      return const {};
    }
  }

  /// Toma un lugar de la BD y le rellena lo que falte:
  /// coordenadas (de `/geo/nearby` o del mock) e imágenes/descripción (del
  /// mock, mientras la BD siga con imágenes de marcador de posición).
  LugarIca _completarConMock(
    LugarIca lugar,
    Map<String, LugarIca> coordenadas,
  ) {
    final cercano = coordenadas[lugar.id];
    return _conRespaldoDeMock(
      lugar.copyWith(
        latitud: lugar.latitud ?? cercano?.latitud,
        longitud: lugar.longitud ?? cercano?.longitud,
      ),
    );
  }

  /// Rellena con el mock equivalente (buscado por nombre) los campos que el
  /// lugar de la BD tenga vacíos. No sobrescribe nada que la BD ya haya dado.
  LugarIca _conRespaldoDeMock(LugarIca lugar) {
    final mock = LugaresMock.porNombre(lugar.nombre);
    if (mock == null) return lugar;

    return lugar.copyWith(
      descripcion: lugar.descripcion.isNotEmpty
          ? lugar.descripcion
          : mock.descripcion,
      categorias: lugar.categorias.isNotEmpty
          ? lugar.categorias
          : mock.categorias,
      latitud: lugar.latitud ?? mock.latitud,
      longitud: lugar.longitud ?? mock.longitud,
      imagenes: _imagenesUtiles(lugar.imagenes).isNotEmpty
          ? _imagenesUtiles(lugar.imagenes)
          : mock.imagenes,
      recomendacionOficial:
          lugar.recomendacionOficial ?? mock.recomendacionOficial,
    );
  }

  /// Descarta las URLs de marcador de posición que hoy tiene la semilla de la
  /// BD (`placehold.co`), para no mostrar imágenes grises al usuario.
  List<String> _imagenesUtiles(List<String> imagenes) {
    return imagenes
        .where((url) => url.isNotEmpty && !url.contains('placehold.co'))
        .toList();
  }
}
