import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ika_travel_mobile/services/api_client.dart';
import 'package:ika_travel_mobile/services/attractions_service.dart';

void main() {
  group('AttractionsService Tests', () {
    test('getAttractions parsea correctamente la respuesta del backend', () async {
      final mockResponse = {
        'items': [
          {
            'id': 'd290f1ee-6c54-4b01-90e6-d701748f0851',
            'name': 'Oasis de Huacachina',
            'district': 'Ica',
            'cover_image_url': 'https://example.com/huacachina.jpg',
            'categories': ['Aventura', 'Naturaleza'],
          }
        ],
        'total': 1,
        'page': 1,
        'page_size': 20,
        'has_next': false,
      };

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/catalog/attractions');
        expect(request.url.queryParameters['search'], 'huacachina');
        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AttractionsService(apiClient: ApiClient(client: mockClient));
      final items = await service.getAttractions(search: 'huacachina');

      expect(items.length, 1);
      expect(items.first.name, 'Oasis de Huacachina');
      expect(items.first.district, 'Ica');
      expect(items.first.categories, ['Aventura', 'Naturaleza']);
    });

    test('getAttractionDetail parsea correctamente el detalle', () async {
      final mockResponse = {
        'id': 'd290f1ee-6c54-4b01-90e6-d701748f0851',
        'name': 'Oasis de Huacachina',
        'description': 'Laguna natural rodeada de palmeras y dunas.',
        'official_recommendation': 'Visitar al atardecer.',
        'district': 'Ica',
        'latitude': -14.0875,
        'longitude': -75.7628,
        'images': ['https://example.com/h1.jpg'],
        'categories': [{'id': '1', 'name': 'Aventura', 'slug': 'aventura'}],
        'avg_rating': 4.8,
      };

      final mockClient = MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/catalog/attractions/d290f1ee-6c54-4b01-90e6-d701748f0851',
        );
        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AttractionsService(apiClient: ApiClient(client: mockClient));
      final detail = await service.getAttractionDetail('d290f1ee-6c54-4b01-90e6-d701748f0851');

      expect(detail.name, 'Oasis de Huacachina');
      expect(detail.latitude, -14.0875);
      expect(detail.avgRating, 4.8);
      expect(detail.categories, ['Aventura']);
    });
  });
}
