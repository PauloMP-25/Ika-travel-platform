import 'package:flutter_test/flutter_test.dart';
import 'package:ika_travel_mobile/services/texto_ia.dart';

/// La IA devuelve el texto adornado con emojis en tiempo de ejecución, así
/// que no se puede limpiar en el código fuente: hay que hacerlo al recibirlo.
void main() {
  group('TextoIA.limpiar', () {
    test('quita los emojis del texto de la IA', () {
      const crudo = '☀️ ¡Día perfecto para las dunas! 🏜️ Lleva agua 💧';
      final limpio = TextoIA.limpiar(crudo);

      expect(limpio, '¡Día perfecto para las dunas! Lleva agua');
      expect(limpio, isNot(contains('☀')));
      expect(limpio, isNot(contains('🏜')));
    });

    test('conserva las tildes, la eñe y los signos del español', () {
      final limpio = TextoIA.limpiar('🌞 Protección solar en Huacachina: ¿vas?');
      expect(limpio, 'Protección solar en Huacachina: ¿vas?');
    });

    test('no deja espacios dobles donde estaba el emoji', () {
      final limpio = TextoIA.limpiar('Usa 🧴 bloqueador 😎 siempre');
      expect(limpio, 'Usa bloqueador siempre');
      expect(limpio.contains('  '), isFalse);
    });

    test('tolera null y cadena vacía', () {
      expect(TextoIA.limpiar(null), isEmpty);
      expect(TextoIA.limpiar(''), isEmpty);
    });

    test('un texto que ya venía limpio no se altera', () {
      const texto = 'Condiciones óptimas con 26°C y cielo despejado.';
      expect(TextoIA.limpiar(texto), texto);
    });

    test('limpiarLista descarta los consejos que quedaban vacíos', () {
      final lista = TextoIA.limpiarLista([
        '🧴 Bloqueador FPS 50+',
        '✨',
        'Hidrátate seguido',
        null,
      ]);

      expect(lista, ['Bloqueador FPS 50+', 'Hidrátate seguido']);
    });
  });
}
