import '../models/attraction_model.dart';
import 'api_client.dart';

class AttractionsService {
  final ApiClient _apiClient;

  AttractionsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Obtiene la lista de atractivos turísticos con filtros opcionales de búsqueda y categoría.
  Future<List<AttractionListItemModel>> getAttractions({
    String? category,
    String? district,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (district != null && district.isNotEmpty) {
        queryParams['district'] = district;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final data = await _apiClient.get('/catalog/attractions?$queryString');

      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((item) =>
              AttractionListItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback local en caso el backend esté desconectado
      return const [
        AttractionListItemModel(
          id: '1',
          name: 'Huacachina Sandboarding & Buggy',
          district: 'Ica',
          coverImageUrl: 'assets/images/carrusel_1_huacachina.jpg',
          categories: ['Aventura', 'Desierto'],
        ),
        AttractionListItemModel(
          id: '2',
          name: 'Islas Ballestas',
          district: 'Paracas',
          coverImageUrl: 'assets/images/carrusel_2_paracas.jpg',
          categories: ['Naturaleza', 'Fauna'],
        ),
        AttractionListItemModel(
          id: '3',
          name: 'Líneas de Nazca',
          district: 'Nazca',
          coverImageUrl: 'assets/images/carrusel_3_lineas.jpg',
          categories: ['Cultura', 'Historia'],
        ),
        AttractionListItemModel(
          id: '4',
          name: 'Ruta del Pisco y Viñedos',
          district: 'Ica',
          coverImageUrl: 'assets/images/carrusel_4_vinas.jpg',
          categories: ['Gastronomía', 'Tradición'],
        ),
      ];
    }
  }

  /// Obtiene el detalle completo de un atractivo por su identificador UUID.
  Future<AttractionDetailModel> getAttractionDetail(String attractionId) async {
    try {
      final data = await _apiClient.get('/catalog/attractions/$attractionId');
      return AttractionDetailModel.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return AttractionDetailModel(
        id: attractionId,
        name: 'Atractivo turístico en Ica',
        description:
            'Disfruta de uno de los mejores destinos turísticos del departamento de Ica.',
        district: 'Ica',
        latitude: -14.0875,
        longitude: -75.7626,
        images: const ['assets/images/carrusel_1_huacachina.jpg'],
        categories: const ['Turismo'],
      );
    }
  }
}
