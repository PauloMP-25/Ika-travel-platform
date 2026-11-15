import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Un lugar turístico del catálogo de Ica.
///
/// Es el **único** modelo de lugar del frontend: lo comparten la galería
/// (Actividades), el mapa y la pantalla de detalle, de modo que los tres
/// muestran siempre lo mismo.
///
/// La fuente de verdad es la base de datos, a través de
/// `GET /catalog/attractions` (listado), `GET /geo/nearby` (coordenadas) y
/// `GET /catalog/attractions/{id}` (detalle). Si la API falla, se completan
/// con los mocks espejo de `LugaresMock` para que la app nunca se vea vacía.
@immutable
class LugarIca {
  /// UUID del atractivo en la base de datos (`attraction.id`).
  final String id;

  /// `attraction.name`.
  final String nombre;

  /// `attraction.district`.
  final String distrito;

  /// `attraction.description`. El endpoint de listado no la devuelve, así que
  /// puede llegar vacía hasta que se abra el detalle.
  final String descripcion;

  /// Nombres de categoría tal como están en la BD (`category.name`):
  /// "Sandboarding", "Aventura", "Cultural", "Gastronomía y vino", "Naturaleza".
  final List<String> categorias;

  /// `attraction.latitude` / `attraction.longitude`. Nulos si el backend aún
  /// no las entregó (el listado paginado no incluye coordenadas).
  final double? latitud;
  final double? longitud;

  /// URLs remotas (`attraction_image.url`) o rutas de assets locales.
  final List<String> imagenes;

  /// `attraction.official_recommendation`.
  final String? recomendacionOficial;

  /// Promedio de reseñas (solo lo devuelve el detalle).
  final double? ratingPromedio;

  /// `true` cuando los datos provienen de los mocks locales y no de la BD.
  final bool esMock;

  const LugarIca({
    required this.id,
    required this.nombre,
    required this.distrito,
    this.descripcion = '',
    this.categorias = const [],
    this.latitud,
    this.longitud,
    this.imagenes = const [],
    this.recomendacionOficial,
    this.ratingPromedio,
    this.esMock = false,
  });

  /// Asset usado cuando un lugar no tiene ninguna imagen asociada.
  static const String imagenPorDefecto =
      'assets/images/carrusel_1_huacachina.jpg';

  bool get tieneCoordenadas => latitud != null && longitud != null;

  /// Punto para el mapa. Nulo si el lugar todavía no tiene coordenadas.
  LatLng? get coordenadas =>
      tieneCoordenadas ? LatLng(latitud!, longitud!) : null;

  /// Categoría que define el color y el icono del lugar.
  String get categoriaPrincipal =>
      categorias.isNotEmpty ? categorias.first : 'Turismo';

  String get imagenPrincipal =>
      imagenes.isNotEmpty ? imagenes.first : imagenPorDefecto;

  /// Imágenes para el carrusel del detalle (nunca vacío).
  List<String> get imagenesDetalle =>
      imagenes.isNotEmpty ? imagenes : const [imagenPorDefecto];

  EstiloCategoria get estilo => CategoriasLugar.estilo(categoriaPrincipal);

  /// ¿El lugar coincide con un texto libre de búsqueda?
  bool coincideCon(String consulta) {
    final q = _normalizar(consulta.trim());
    if (q.isEmpty) return true;
    return _normalizar(nombre).contains(q) ||
        _normalizar(distrito).contains(q) ||
        _normalizar(descripcion).contains(q) ||
        categorias.any((c) => _normalizar(c).contains(q));
  }

  /// ¿El lugar pertenece a una categoría? Tolera acentos y variantes
  /// ("Cultura" ↔ "Cultural", "Gastronomía" ↔ "Gastronomía y vino").
  bool esDeCategoria(String categoria) {
    final filtro = _normalizar(categoria);
    if (filtro.isEmpty) return true;
    return categorias.any((c) {
      final actual = _normalizar(c);
      return actual == filtro ||
          actual.contains(filtro) ||
          filtro.contains(actual);
    });
  }

  LugarIca copyWith({
    String? id,
    String? nombre,
    String? distrito,
    String? descripcion,
    List<String>? categorias,
    double? latitud,
    double? longitud,
    List<String>? imagenes,
    String? recomendacionOficial,
    double? ratingPromedio,
    bool? esMock,
  }) {
    return LugarIca(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      distrito: distrito ?? this.distrito,
      descripcion: descripcion ?? this.descripcion,
      categorias: categorias ?? this.categorias,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      imagenes: imagenes ?? this.imagenes,
      recomendacionOficial: recomendacionOficial ?? this.recomendacionOficial,
      ratingPromedio: ratingPromedio ?? this.ratingPromedio,
      esMock: esMock ?? this.esMock,
    );
  }

  // ------------------------------------------------------------------
  // Constructores desde la API
  // ------------------------------------------------------------------

  /// `AttractionListItem`: id, name, district, cover_image_url, categories.
  /// No trae coordenadas ni descripción (ver pendientes del backend).
  factory LugarIca.deListado(Map<String, dynamic> json) {
    final portada = json['cover_image_url']?.toString();
    return LugarIca(
      id: json['id']?.toString() ?? '',
      nombre: json['name']?.toString() ?? 'Sin nombre',
      distrito: json['district']?.toString() ?? 'Ica',
      categorias: _categoriasDe(json['categories']),
      imagenes: (portada != null && portada.isNotEmpty) ? [portada] : const [],
    );
  }

  /// `AttractionNearbyItem` de `/geo/nearby`: igual que el listado, pero **con**
  /// latitud y longitud.
  factory LugarIca.deCercanos(Map<String, dynamic> json) {
    final portada = json['cover_image_url']?.toString();
    return LugarIca(
      id: json['id']?.toString() ?? '',
      nombre: json['name']?.toString() ?? 'Sin nombre',
      distrito: json['district']?.toString() ?? 'Ica',
      categorias: _categoriasDe(json['categories']),
      latitud: (json['latitude'] as num?)?.toDouble(),
      longitud: (json['longitude'] as num?)?.toDouble(),
      imagenes: (portada != null && portada.isNotEmpty) ? [portada] : const [],
    );
  }

  /// `AttractionDetailResponse`: todo, incluidas coordenadas e imágenes.
  factory LugarIca.deDetalle(Map<String, dynamic> json) {
    final imagenes = (json['images'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return LugarIca(
      id: json['id']?.toString() ?? '',
      nombre: json['name']?.toString() ?? 'Sin nombre',
      distrito: json['district']?.toString() ?? 'Ica',
      descripcion: json['description']?.toString() ?? '',
      categorias: _categoriasDe(json['categories']),
      latitud: (json['latitude'] as num?)?.toDouble(),
      longitud: (json['longitude'] as num?)?.toDouble(),
      imagenes: imagenes,
      recomendacionOficial: json['official_recommendation']?.toString(),
      ratingPromedio: (json['avg_rating'] as num?)?.toDouble(),
    );
  }

  /// Forma con la que `favoritos_manager` guarda los favoritos en el
  /// dispositivo. Se mantiene para no invalidar los ya guardados.
  Map<String, dynamic> aFavorito() => {
    'id': id,
    'titulo': nombre,
    'subtitulo': distrito,
    'categoria': categoriaPrincipal,
    'imagen': imagenPrincipal,
    'imagenes_detalle': imagenesDetalle,
  };

  /// Reconstruye un lugar a partir de un favorito guardado.
  factory LugarIca.deFavorito(Map<String, dynamic> fav) {
    final imagenes = (fav['imagenes_detalle'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final portada = fav['imagen']?.toString();
    final categoria = fav['categoria']?.toString();

    return LugarIca(
      id: fav['id']?.toString() ?? '',
      nombre: fav['titulo']?.toString() ?? 'Sin nombre',
      distrito: fav['subtitulo']?.toString() ?? 'Ica',
      categorias: (categoria != null && categoria.isNotEmpty)
          ? [categoria]
          : const [],
      imagenes: (imagenes != null && imagenes.isNotEmpty)
          ? imagenes
          : (portada != null && portada.isNotEmpty ? [portada] : const []),
    );
  }

  /// Las categorías llegan como `["Aventura"]` en el listado y como
  /// `[{id, name, slug}]` en el detalle.
  static List<String> _categoriasDe(dynamic bruto) {
    if (bruto is! List) return const [];
    return bruto
        .map((c) {
          if (c is Map) return c['name']?.toString() ?? '';
          return c.toString();
        })
        .where((c) => c.isNotEmpty)
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      other is LugarIca && other.id == id && other.nombre == nombre;

  @override
  int get hashCode => Object.hash(id, nombre);

  @override
  String toString() => 'LugarIca($nombre, $distrito)';
}

/// Color e icono de una categoría. Compartido por el mapa, la galería y los
/// filtros para que un mismo tipo de lugar se vea igual en toda la app.
@immutable
class EstiloCategoria {
  final Color color;
  final IconData icono;

  const EstiloCategoria(this.color, this.icono);
}

/// Estilos de las categorías de la base de datos, con colores vivos y
/// contrastados. Si llega una categoría nueva desde la BD, cae al estilo
/// genérico en vez de romperse.
class CategoriasLugar {
  const CategoriasLugar._();

  static const EstiloCategoria generica = EstiloCategoria(
    Color(0xFF0E9AA7), // turquesa oasis
    Icons.place_rounded,
  );

  static const Map<String, EstiloCategoria> _porClave = {
    'sandboarding': EstiloCategoria(
      Color(0xFFFFB300), // amarillo duna
      Icons.snowboarding_rounded,
    ),
    'aventura': EstiloCategoria(
      Color(0xFFF26419), // naranja
      Icons.terrain_rounded,
    ),
    'naturaleza': EstiloCategoria(
      Color(0xFF27C06B), // verde vivo
      Icons.park_rounded,
    ),
    'cultural': EstiloCategoria(
      Color(0xFF2BB7E3), // celeste
      Icons.account_balance_rounded,
    ),
    'gastronomia': EstiloCategoria(
      Color(0xFFB5179E), // morado vino
      Icons.wine_bar_rounded,
    ),
  };

  static EstiloCategoria estilo(String categoria) {
    final clave = _normalizar(categoria);
    for (final entrada in _porClave.entries) {
      if (clave.contains(entrada.key) || entrada.key.contains(clave)) {
        return entrada.value;
      }
    }
    return generica;
  }
}

/// Minúsculas y sin acentos, para comparar textos de la BD con los del filtro.
String _normalizar(String texto) {
  var t = texto.toLowerCase().trim();
  const acentos = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  acentos.forEach((con, sin) => t = t.replaceAll(con, sin));
  return t;
}
