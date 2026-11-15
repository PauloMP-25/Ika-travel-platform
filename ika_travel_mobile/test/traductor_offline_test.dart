import 'package:flutter_test/flutter_test.dart';
import 'package:ika_travel_mobile/services/traductor_offline.dart';

/// El traductor sin conexión es el último recurso cuando el backend no
/// responde y tampoco hay internet para la IA. Lo que se prueba aquí es que
/// devuelva algo útil y que avise cuando la traducción quedó incompleta.
void main() {
  group('TraductorOffline', () {
    test('traduce expresiones completas, no palabra por palabra', () {
      final res = TraductorOffline.traducir(
        texto: '¿Cuánto cuesta?',
        origen: 'es',
        destino: 'en',
      );

      expect(res.texto.toLowerCase(), contains('how much does it cost'));
      expect(res.aproximada, isFalse);
    });

    test('prefiere la expresión más larga sobre la palabra suelta', () {
      // "donde esta" debe ganarle a "donde" + "esta" por separado.
      final res = TraductorOffline.traducir(
        texto: '¿Dónde está el hospital?',
        origen: 'es',
        destino: 'en',
      );

      expect(res.texto.toLowerCase(), contains('where is'));
      expect(res.texto.toLowerCase(), contains('hospital'));
    });

    test('ignora tildes y mayúsculas al buscar en el diccionario', () {
      final conTildes = TraductorOffline.traducir(
        texto: 'Necesito ayuda',
        origen: 'es',
        destino: 'en',
      );
      final sinTildes = TraductorOffline.traducir(
        texto: 'NECESITO AYUDA',
        origen: 'es',
        destino: 'en',
      );

      expect(conTildes.texto.toLowerCase(), sinTildes.texto.toLowerCase());
      expect(conTildes.texto.toLowerCase(), contains('i need help'));
    });

    test('traduce también de inglés a español', () {
      final res = TraductorOffline.traducir(
        texto: 'Where is the beach?',
        origen: 'en',
        destino: 'es',
      );

      expect(res.texto.toLowerCase(), contains('playa'));
    });

    test('marca como aproximada cuando hay palabras desconocidas', () {
      final res = TraductorOffline.traducir(
        texto: 'Quiero zarandajas',
        origen: 'es',
        destino: 'en',
      );

      expect(res.aproximada, isTrue);
      expect(res.cobertura, lessThan(1.0));
      // La palabra desconocida se conserva: es preferible a borrarla.
      expect(res.texto.toLowerCase(), contains('zarandajas'));
    });

    test('nunca devuelve texto vacío ni el marcador de relleno anterior', () {
      const frases = [
        'Hola, buenos días',
        'Me siento mal',
        'La cuenta por favor',
        'Quiero ir a la Plaza de Armas',
      ];

      for (final frase in frases) {
        final res = TraductorOffline.traducir(
          texto: frase,
          origen: 'es',
          destino: 'en',
        );
        expect(res.texto.trim(), isNotEmpty, reason: 'Falló con "$frase"');
        expect(res.texto.toLowerCase(), isNot(contains('simulada')));
        expect(res.texto.toLowerCase(), isNot(contains('offline-fallback')));
      }
    });

    test('conserva los signos de interrogación y cierre', () {
      final res = TraductorOffline.traducir(
        texto: '¿Habla inglés?',
        origen: 'es',
        destino: 'en',
      );

      expect(res.texto, endsWith('?'));
      expect(res.texto, isNot(contains('¿')));
    });

    test('solo admite los pares de idiomas que cubre el diccionario', () {
      expect(TraductorOffline.soporta('es', 'en'), isTrue);
      expect(TraductorOffline.soporta('en', 'es'), isTrue);
      expect(TraductorOffline.soporta('es', 'es'), isFalse);
      expect(TraductorOffline.soporta('es', 'ja'), isFalse);
    });
  });
}
