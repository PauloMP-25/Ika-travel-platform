class AttractionListItemModel {
  final String id;
  final String name;
  final String district;
  final String? coverImageUrl;
  final List<String> categories;

  const AttractionListItemModel({
    required this.id,
    required this.name,
    required this.district,
    this.coverImageUrl,
    required this.categories,
  });

  factory AttractionListItemModel.fromJson(Map<String, dynamic> json) {
    return AttractionListItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      district: json['district'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': name,
      'subtitulo': district,
      'imagen': coverImageUrl ?? 'assets/images/detalle_sandboarding_1.jpg',
      'imagenes_detalle': [
        coverImageUrl ?? 'assets/images/detalle_sandboarding_1.jpg',
      ],
      'categorias': categories,
    };
  }
}

class AttractionDetailModel {
  final String id;
  final String name;
  final String description;
  final String? officialRecommendation;
  final String district;
  final double latitude;
  final double longitude;
  final List<String> images;
  final List<String> categories;
  final double? avgRating;

  const AttractionDetailModel({
    required this.id,
    required this.name,
    required this.description,
    this.officialRecommendation,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.categories,
    this.avgRating,
  });

  factory AttractionDetailModel.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'] as List<dynamic>? ?? [];
    final List<String> parsedCategories = rawCategories.map((c) {
      if (c is Map<String, dynamic>) {
        return c['name']?.toString() ?? '';
      }
      return c.toString();
    }).toList();

    return AttractionDetailModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      officialRecommendation: json['official_recommendation'] as String?,
      district: json['district'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      images: (json['images'] as List<dynamic>?)
              ?.map((img) => img.toString())
              .toList() ??
          [],
      categories: parsedCategories,
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
    );
  }
}
