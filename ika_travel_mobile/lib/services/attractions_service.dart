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
  }

  /// Obtiene el detalle completo de un atractivo por su identificador UUID.
  Future<AttractionDetailModel> getAttractionDetail(String attractionId) async {
    final data = await _apiClient.get('/catalog/attractions/$attractionId');
    return AttractionDetailModel.fromJson(data as Map<String, dynamic>);
  }
}
