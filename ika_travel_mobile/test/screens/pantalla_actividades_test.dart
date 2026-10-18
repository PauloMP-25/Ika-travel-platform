import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ika_travel_mobile/models/attraction_model.dart';
import 'package:ika_travel_mobile/screens/pantalla_actividades.dart';
import 'package:ika_travel_mobile/services/attractions_service.dart';

class MockAttractionsServiceSuccess implements AttractionsService {
  @override
  Future<List<AttractionListItemModel>> getAttractions({
    String? category,
    String? district,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    return [
      const AttractionListItemModel(
        id: '1',
        name: 'Laguna de Huacachina',
        district: 'Ica',
        coverImageUrl: 'assets/images/carrusel_1_huacachina.jpg',
        categories: ['Aventura'],
      ),
      const AttractionListItemModel(
        id: '2',
        name: 'Líneas de Nazca',
        district: 'Nazca',
        coverImageUrl: 'assets/images/carrusel_2_vinos.jpg',
        categories: ['Cultura'],
      ),
    ];
  }

  @override
  Future<AttractionDetailModel> getAttractionDetail(String attractionId) async {
    throw UnimplementedError();
  }
}

class MockAttractionsServiceError implements AttractionsService {
  @override
  Future<List<AttractionListItemModel>> getAttractions({
    String? category,
    String? district,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw Exception('Error de conexión con el backend');
  }

  @override
  Future<AttractionDetailModel> getAttractionDetail(String attractionId) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('PantallaActividades muestra datos del backend cuando hay conexión', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaActividades(
          attractionsService: MockAttractionsServiceSuccess(),
        ),
      ),
    );

    // Inicialmente cargando
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Esperar a que resuelva el servicio
    await tester.pumpAndSettle();

    expect(find.text('Laguna de Huacachina'), findsOneWidget);
    expect(find.text('Líneas de Nazca'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('PantallaActividades usa fallback local y aviso si el backend falla', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaActividades(
          attractionsService: MockAttractionsServiceError(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Muestra aviso de modo sin conexión
    expect(find.text('Modo sin conexión: mostrando catálogo local.'), findsOneWidget);
    // Muestra las actividades locales de fallback
    expect(find.text('Sandboarding\nen Huacachina'), findsOneWidget);
  });
}
