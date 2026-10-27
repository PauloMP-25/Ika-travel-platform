import 'package:flutter_test/flutter_test.dart';
import 'package:ika_travel_mobile/services/gemini_service.dart';
import 'package:ika_travel_mobile/services/weather_service.dart';

void main() {
  group('GeminiService & Weather AI Fallback Tests', () {
    final geminiService = GeminiService();
    final weatherService = WeatherService();

    test('GeminiService genera recomendación offline con estructura completa', () {
      final rec = geminiService.obtenerRecomendacionOffline(
        nombreAtractivo: 'Oasis de Huacachina',
        temperatura: 26.0,
        viento: 14.0,
        uv: 9.0,
        condicion: 'Cielo despejado con sol radiante',
      );

      expect(rec['atractivo_nombre'], equals('Oasis de Huacachina'));
      expect(rec['score'], isNotNull);
      expect(rec['score'], greaterThan(0.7));
      expect(rec['nivel'], equals('excelente'));
      expect(rec['recommendation_text'], contains('Oasis de Huacachina'));
      expect(rec['consejos'], isA<List<String>>());
      expect((rec['consejos'] as List).isNotEmpty, isTrue);
      expect(rec['source'], equals('gemini_engine_fallback'));
    });

    test('GeminiService ajusta recomendaciones ante ráfagas de viento y calor extremo', () {
      final recViento = geminiService.obtenerRecomendacionOffline(
        nombreAtractivo: 'Dunas de Huacachina',
        temperatura: 31.0,
        viento: 32.0,
        uv: 11.0,
        condicion: 'Paracas / Viento fuerte',
      );

      expect(recViento['nivel'], equals('bueno'));
      expect(recViento['consejos'], anyElement(contains('cortavientos')));
      expect(recViento['consejos'], anyElement(contains('calzado')));
    });

    test('GeminiService provee catálogo de recomendaciones para atractivos icónicos de Ica', () {
      final catalogo = geminiService.obtenerCatalogoRecomendacionesOffline();

      expect(catalogo.length, greaterThanOrEqualTo(4));
      final nombres = catalogo.map((e) => e['atractivo_nombre']).toList();
      expect(nombres, contains('Oasis de Huacachina'));
      expect(nombres, contains('Islas Ballestas (Paracas)'));
      expect(nombres, contains('Bodega Tacama'));
      expect(nombres, contains('Cañón de los Perdidos'));
    });

    test('WeatherService obtenerRecomendacionDelDia retorna datos válidos para la UI', () async {
      final rec = await weatherService.obtenerRecomendacionDelDia();

      expect(rec, isNotNull);
      expect(rec!['recommendation_text'], isNotNull);
      expect((rec['recommendation_text'] as String).isNotEmpty, isTrue);
      expect(rec['consejos'], isA<List>());
    });

    test('WeatherService obtenerPronostico retorna horas y días garantizados para frontend', () async {
      final pronostico = await weatherService.obtenerPronostico(days: 7);

      expect(pronostico, isNotNull);
      expect(pronostico!['destino'], equals('Ica'));
      expect(pronostico['horas'], isA<List>());
      expect((pronostico['horas'] as List).length, equals(24));
      expect(pronostico['dias'], isA<List>());
      expect((pronostico['dias'] as List).length, equals(7));
    });
  });
}
