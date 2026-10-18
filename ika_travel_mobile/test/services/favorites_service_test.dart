import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ika_travel_mobile/services/api_client.dart';
import 'package:ika_travel_mobile/services/favorites_service.dart';

void main() {
  group('FavoritesService', () {
    const testUuid = '123e4567-e89b-12d3-a456-426614174000';

    test('toggleRemoteFavorite llama a /catalog/attractions/{id}/favorite y retorna is_favorite', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/favorite') && request.method == 'POST') {
          return http.Response(
            json.encode({'attraction_id': testUuid, 'is_favorite': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final service = FavoritesService(apiClient: apiClient);

      final res = await service.toggleRemoteFavorite(testUuid);
      expect(res, true);
    });

    test('checkIsFavorite consulta el endpoint /is-favorite', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/is-favorite')) {
          return http.Response(json.encode(true), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final service = FavoritesService(apiClient: apiClient);

      final isFav = await service.checkIsFavorite(testUuid);
      expect(isFav, true);
    });
  });
}
