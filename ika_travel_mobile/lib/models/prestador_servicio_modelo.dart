import 'package:flutter/foundation.dart';

/// Modelos de Prestador de Servicios Turísticos y Tours para Ika Travel.
/// Cumple con la regla RN-01: Exclusivamente prestadores empadronados y validados por DIRCETUR.
class TourPrestadorModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationHours;
  final String agencyId;
  final String agencyName;
  final String? attractionName;

  const TourPrestadorModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationHours,
    required this.agencyId,
    required this.agencyName,
    this.attractionName,
  });

  factory TourPrestadorModel.fromJson(Map<String, dynamic> json) {
    return TourPrestadorModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Tour sin nombre',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationHours: (json['duration_hours'] as num?)?.toInt() ?? 1,
      agencyId: json['agency_id']?.toString() ?? '',
      agencyName: json['agency_name']?.toString() ?? '',
      attractionName: json['attraction_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration_hours': durationHours,
      'agency_id': agencyId,
      'agency_name': agencyName,
      'attraction_name': attractionName,
    };
  }
}

class PrestadorServicioModel {
  final String id;
  final String name;
  final bool isValidated;
  final String? ruc;
  final String? dirceturRegistryNumber;
  final String? contactPhone;
  final String? contactEmail;
  final int tourCount;
  final List<TourPrestadorModel> tours;

  const PrestadorServicioModel({
    required this.id,
    required this.name,
    required this.isValidated,
    this.ruc,
    this.dirceturRegistryNumber,
    this.contactPhone,
    this.contactEmail,
    this.tourCount = 0,
    this.tours = const [],
  });

  bool get esFormalValidado => isValidated;

  factory PrestadorServicioModel.fromJson(Map<String, dynamic> json) {
    final rawTours = json['tours'] as List<dynamic>? ?? [];
    final toursList = rawTours
        .map((t) => TourPrestadorModel.fromJson(t as Map<String, dynamic>))
        .toList();

    return PrestadorServicioModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Prestador sin nombre',
      isValidated: json['is_validated'] == true,
      ruc: json['ruc']?.toString(),
      dirceturRegistryNumber: json['dircetur_registry_number']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      contactEmail: json['contact_email']?.toString(),
      tourCount: (json['tour_count'] as num?)?.toInt() ?? toursList.length,
      tours: toursList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_validated': isValidated,
      'ruc': ruc,
      'dircetur_registry_number': dirceturRegistryNumber,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'tour_count': tourCount,
      'tours': tours.map((t) => t.toJson()).toList(),
    };
  }

  PrestadorServicioModel copyWith({
    String? id,
    String? name,
    bool? isValidated,
    String? ruc,
    String? dirceturRegistryNumber,
    String? contactPhone,
    String? contactEmail,
    int? tourCount,
    List<TourPrestadorModel>? tours,
  }) {
    return PrestadorServicioModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isValidated: isValidated ?? this.isValidated,
      ruc: ruc ?? this.ruc,
      dirceturRegistryNumber:
          dirceturRegistryNumber ?? this.dirceturRegistryNumber,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      tourCount: tourCount ?? this.tourCount,
      tours: tours ?? this.tours,
    );
  }
}

/// Notificador global para que el Panel DIRCETUR y la Pantalla de Prestadores
/// compartan los mismos datos en tiempo real.
final ValueNotifier<List<PrestadorServicioModel>> prestadoresGlobales =
    ValueNotifier<List<PrestadorServicioModel>>([
      const PrestadorServicioModel(
        id: 'ag-dircetur-001',
        name: 'Ica Desert & Dune Buggy Tours S.A.C.',
        isValidated: true,
        ruc: '20601234567',
        dirceturRegistryNumber: 'DIRCETUR-ICA-AG-2024-042',
        contactPhone: '+51 956 123 456',
        contactEmail: 'operaciones@icadesert.pe',
        tourCount: 2,
        tours: [
          TourPrestadorModel(
            id: 't-01',
            name: 'Circuito Safari Buggy',
            description: 'Paseo en tubulares.',
            price: 55.0,
            durationHours: 2,
            agencyId: 'ag-dircetur-001',
            agencyName: 'Ica Desert',
            attractionName: 'Huacachina',
          ),
        ],
      ),
      const PrestadorServicioModel(
        id: 'ag-dircetur-002',
        name: 'Paracas Bahía Marina Travel',
        isValidated: true,
        ruc: '20534567891',
        dirceturRegistryNumber: 'DIRCETUR-ICA-AG-2023-118',
        contactPhone: '+51 987 654 321',
        contactEmail: 'informes@paracasmarina.pe',
        tourCount: 1,
        tours: [
          TourPrestadorModel(
            id: 't-03',
            name: 'Navegación Islas Ballestas',
            description: 'Zarpe desde El Chaco.',
            price: 50.0,
            durationHours: 2,
            agencyId: 'ag-dircetur-002',
            agencyName: 'Paracas',
            attractionName: 'Islas Ballestas',
          ),
        ],
      ),
      const PrestadorServicioModel(
        id: 'ag-dircetur-003',
        name: 'Ruta Pisquera & Viñedos Tradicionales E.I.R.L.',
        isValidated: true,
        ruc: '20498765432',
        dirceturRegistryNumber: 'DIRCETUR-ICA-AG-2024-009',
        contactPhone: '+51 956 789 123',
        contactEmail: 'tours@rutapisqueraica.com',
        tourCount: 1,
        tours: [
          TourPrestadorModel(
            id: 't-05',
            name: 'Cata guiada en bodegas',
            description: 'Visita a bodega histórica.',
            price: 75.0,
            durationHours: 4,
            agencyId: 'ag-dircetur-003',
            agencyName: 'Ruta Pisquera',
            attractionName: 'Ruta del Pisco',
          ),
        ],
      ),
    ]);
