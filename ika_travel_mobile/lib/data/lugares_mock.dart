import '../models/lugar_modelo.dart';

/// Catálogo local de respaldo (**espejo exacto** de la semilla oficial de la
/// base de datos: `ika-backend/src/modules/catalog/seed.py` → `ATRACTIVOS`).
///
/// ¿Para qué existe? Para que la app **nunca** se muestre vacía: si el backend
/// está caído, sin internet o devuelve una lista vacía, la galería, el mapa y
/// el detalle siguen funcionando con estos datos. Son los mismos nombres,
/// coordenadas, distritos y categorías que hay en la BD, así que el usuario ve
/// la misma información esté o no conectado.
///
/// Además sirve para completar lo que la API **todavía no entrega**:
/// - las coordenadas que faltan en `GET /catalog/attractions` (listado), y
/// - las imágenes, mientras `attraction_image` siga con URLs de marcador de
///   posición (`placehold.co`) en vez de fotos reales.
///
/// ⚠️ Si se agregan atractivos a la BD, hay que reflejarlos aquí para que el
/// modo sin conexión siga coincidiendo con la BD.
class LugaresMock {
  const LugaresMock._();

  /// Nombres de categoría tal como están en `category.name` de la BD.
  static const List<String> categorias = [
    'Sandboarding',
    'Aventura',
    'Cultural',
    'Gastronomía y vino',
    'Naturaleza',
  ];

  static const List<LugarIca> lugares = [
    LugarIca(
      id: 'mock-huacachina',
      nombre: 'Oasis de Huacachina',
      distrito: 'Ica',
      descripcion:
          'Laguna natural rodeada de dunas, punto de partida de paseos en '
          'buggy y sandboarding.',
      categorias: ['Sandboarding', 'Aventura', 'Naturaleza'],
      latitud: -14.087265,
      longitud: -75.763105,
      recomendacionOficial:
          'Lleva protector solar, lentes y evita el mediodía en temporada de '
          'verano.',
      imagenes: [
        'assets/images/carrusel_1_huacachina.jpg',
        'assets/images/detalle_sandboarding_1.jpg',
        'assets/images/detalle_sandboarding_2.jpg',
        'assets/images/detalle_sandboarding_3.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-cachiche',
      nombre: 'Palmera de las 7 Cabezas (Cachiche)',
      distrito: 'Ica',
      descripcion:
          'Lugar tradicional conocido por la enigmática Palmera de las 7 '
          'Cabezas, sus leyendas místicas y la brujería de Cachiche.',
      categorias: ['Cultural'],
      latitud: -14.094789,
      longitud: -75.735570,
      recomendacionOficial:
          'Visita en horas de la mañana para recorrer con menos calor.',
      imagenes: [
        'assets/images/detalle_buggy_2.jpg',
        'assets/images/detalle_buggy_3.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-plaza-ica',
      nombre: 'Plaza de Armas de Ica',
      distrito: 'Ica',
      descripcion:
          'Centro histórico de la ciudad, rodeado de la catedral y edificios '
          'coloniales.',
      categorias: ['Cultural'],
      latitud: -14.063804,
      longitud: -75.728825,
      imagenes: [
        'assets/images/carrusel_3_sandboarding.jpg',
        'assets/images/carrusel_2_vinos.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-tacama',
      nombre: 'Viña Tacama',
      distrito: 'Ica',
      descripcion:
          'La viña y bodega más antigua de Sudamérica, cuna de vinos y piscos '
          'de prestigio internacional.',
      categorias: ['Gastronomía y vino', 'Cultural'],
      latitud: -14.000958,
      longitud: -75.716955,
      recomendacionOficial:
          'Reserva tu recorrido con anticipación y disfruta de la cata '
          'dirigida.',
      imagenes: [
        'assets/images/act_vinos.jpg',
        'assets/images/detalle_vinos_2.jpg',
        'assets/images/detalle_vinos_3.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-sotelo',
      nombre: 'Bodega y Viñedos Sotelo (Subtanjalla)',
      distrito: 'Subtanjalla',
      descripcion:
          'Tradicional viñedo y bodega pisquera artesanal de Subtanjalla, '
          'cuna de vinos y piscos de alta calidad.',
      categorias: ['Gastronomía y vino', 'Cultural'],
      latitud: -14.002123,
      longitud: -75.739003,
      recomendacionOficial:
          'Consume alcohol con responsabilidad y reserva el transporte de '
          'regreso.',
      imagenes: [
        'assets/images/detalle_vinos_2.jpg',
        'assets/images/act_vinos.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-tres-generaciones',
      nombre: 'Bodega Tres Generaciones (Subtanjalla)',
      distrito: 'Subtanjalla',
      descripcion:
          'Bodega tradicional pisquera artesanal con más de un siglo de '
          'tradición en la elaboración de pisco puro y acholado.',
      categorias: ['Gastronomía y vino', 'Cultural'],
      latitud: -14.009363,
      longitud: -75.754251,
      recomendacionOficial:
          'Ideal para recorridos enoturísticos y maridajes con postres '
          'típicos.',
      imagenes: [
        'assets/images/detalle_vinos_3.jpg',
        'assets/images/act_vinos.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-canon-perdidos',
      nombre: 'Cañón de los Perdidos',
      distrito: 'Ocucaje',
      descripcion:
          'Formaciones desérticas y paisajes de gran valor geológico, de '
          'acceso en 4x4.',
      categorias: ['Aventura', 'Naturaleza'],
      latitud: -14.737226,
      longitud: -75.509457,
      recomendacionOficial:
          'Ir con agencia formal: la cobertura de red es limitada. Lleva agua '
          'suficiente.',
      imagenes: [
        'assets/images/act_buggy1.jpg',
        'assets/images/detalle_buggy_3.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-ballestas',
      nombre: 'Islas Ballestas',
      distrito: 'Paracas',
      descripcion:
          'Conjunto de islas rocosas habitadas por lobos marinos, pingüinos '
          'de Humboldt y millones de aves guaneras.',
      categorias: ['Naturaleza', 'Aventura'],
      latitud: -13.735943,
      longitud: -76.394191,
      recomendacionOficial:
          'Embarque en deslizadores autorizados con chaleco salvavidas '
          'obligatorio.',
      imagenes: [
        'assets/images/act_ballestas1.jpg',
        'assets/images/detalle_ballestas_2.jpg',
        'assets/images/detalle_ballestas_3.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-reserva-paracas',
      nombre: 'Reserva Nacional de Paracas',
      distrito: 'Paracas',
      descripcion:
          'Área protegida costera con impresionantes paisajes desérticos y '
          'playas vírgenes.',
      categorias: ['Naturaleza'],
      latitud: -13.911640,
      longitud: -76.318399,
      recomendacionOficial:
          'Respeta los senderos señalizados y no dejes residuos en la '
          'reserva.',
      imagenes: [
        'assets/images/act_reserva1.jpg',
        'assets/images/detalle_reserva_2.jpg',
        'assets/images/detalle_reserva_3.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-playa-roja',
      nombre: 'Playa Roja',
      distrito: 'Paracas',
      descripcion:
          'Singular playa de arena roja volcánica rodeada de acantilados '
          'desérticos en Paracas.',
      categorias: ['Naturaleza'],
      latitud: -13.886700,
      longitud: -76.287200,
      recomendacionOficial:
          'Acceso exclusivamente peatonal en miradores para preservar el '
          'ecosistema.',
      imagenes: [
        'assets/images/detalle_reserva_2.jpg',
        'assets/images/act_reserva1.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-playa-la-mina',
      nombre: 'Playa La Mina',
      distrito: 'Paracas',
      descripcion:
          'Bahía de aguas calmas y cristalinas protegida por cerros '
          'desérticos, ideal para el baño.',
      categorias: ['Naturaleza'],
      latitud: -13.911591,
      longitud: -76.318357,
      recomendacionOficial:
          'Lleva protector solar y sombrilla; el sol es intenso todo el año.',
      imagenes: [
        'assets/images/detalle_reserva_3.jpg',
        'assets/images/act_reserva1.jpg',
      ],
      esMock: true,
    ),
    LugarIca(
      id: 'mock-playa-hermosa-marcona',
      nombre: 'Playa Hermosa de Marcona',
      distrito: 'Marcona',
      descripcion:
          'Hermosa playa y costa virgen de la ensenada de Marcona, rica en '
          'biodiversidad marina.',
      categorias: ['Naturaleza'],
      latitud: -15.358300,
      longitud: -75.175000,
      recomendacionOficial:
          'Excelente punto para observación de fauna marina y fotografía.',
      imagenes: [
        'assets/images/act_reserva1.jpg',
        'assets/images/detalle_reserva_2.jpg',
      ],
      esMock: true,
    ),
  ];

  /// Busca el mock equivalente a un lugar de la BD por su nombre.
  ///
  /// Sirve para rellenar coordenadas e imágenes que la API no entrega. La
  /// comparación ignora acentos, mayúsculas y los paréntesis del nombre
  /// ("Palmera de las 7 Cabezas (Cachiche)" ≡ "palmera de las 7 cabezas").
  static LugarIca? porNombre(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return null;
    final buscado = _clave(nombre);
    for (final lugar in lugares) {
      final actual = _clave(lugar.nombre);
      if (actual == buscado ||
          actual.contains(buscado) ||
          buscado.contains(actual)) {
        return lugar;
      }
    }
    return null;
  }

  static LugarIca? porId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final lugar in lugares) {
      if (lugar.id == id) return lugar;
    }
    return null;
  }

  /// Normaliza un nombre para comparar: sin acentos, sin paréntesis ni
  /// símbolos, en minúsculas y con espacios simples.
  static String _clave(String texto) {
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
    t = t.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    t = t.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
