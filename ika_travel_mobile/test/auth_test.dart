import 'package:flutter_test/flutter_test.dart';
import 'package:ika_travel_mobile/models/usuario_modelo.dart';
import 'package:ika_travel_mobile/services/auth_service.dart';

void main() {
  group('Modelos de Autenticación - UsuarioModelo', () {
    test('Serializa y deserializa JSON correctamente', () {
      const original = UsuarioModelo(
        id: 'usr_123',
        email: 'turista@ikatravel.pe',
        fullName: 'Ana María Gómez',
        phone: '+51 987 654 321',
        role: 'tourist',
        preferredLanguage: 'es',
        preferences: ['vino', 'dunas'],
        token: 'jwt_token_sample',
        esInvitado: false,
      );

      final json = original.toJson();
      final reconstruido = UsuarioModelo.fromJson(json);

      expect(reconstruido.id, equals(original.id));
      expect(reconstruido.email, equals(original.email));
      expect(reconstruido.fullName, equals(original.fullName));
      expect(reconstruido.phone, equals(original.phone));
      expect(reconstruido.role, equals(original.role));
      expect(reconstruido.preferredLanguage, equals(original.preferredLanguage));
      expect(reconstruido.preferences, equals(original.preferences));
      expect(reconstruido.token, equals(original.token));
      expect(reconstruido.esInvitado, isFalse);
    });

    test('UsuarioModelo.invitado() crea usuario con rol guest', () {
      final invitado = UsuarioModelo.invitado();

      expect(invitado.esInvitado, isTrue);
      expect(invitado.role, equals('guest'));
      expect(invitado.fullName, equals('Viajero Invitado'));
    });

    test('UsuarioModelo.demo() crea usuario válido con token', () {
      final demo = UsuarioModelo.demo();

      expect(demo.esInvitado, isFalse);
      expect(demo.email, equals('turista@ikatravel.pe'));
      expect(demo.fullName, isNotEmpty);
      expect(demo.token, isNotNull);
    });

    test('Calcula iniciales correctamente para nombres compuestos y simples', () {
      const userCompuesto = UsuarioModelo(
        id: '1',
        email: 'a@b.com',
        fullName: 'Carlos Fuentes',
      );
      expect(userCompuesto.iniciales, equals('CF'));

      const userSimple = UsuarioModelo(
        id: '2',
        email: 'a@b.com',
        fullName: 'Marina',
      );
      expect(userSimple.iniciales, equals('M'));

      const userVacio = UsuarioModelo(
        id: '3',
        email: 'a@b.com',
        fullName: '',
      );
      expect(userVacio.iniciales, equals('IT'));
    });

    test('copyWith preserva valores no especificados', () {
      const original = UsuarioModelo(
        id: '1',
        email: 'original@ika.pe',
        fullName: 'Original Name',
      );

      final modificado = original.copyWith(fullName: 'Nuevo Nombre');
      expect(modificado.id, equals('1'));
      expect(modificado.email, equals('original@ika.pe'));
      expect(modificado.fullName, equals('Nuevo Nombre'));
    });
  });

  group('AuthService - Flujo de sesión', () {
    late AuthService auth;

    setUp(() {
      auth = AuthService();
      auth.usuarioNotifier.value = null;
    });

    test('Estado inicial sin autenticar', () {
      expect(auth.estaAutenticado, isFalse);
      expect(auth.usuarioActual, isNull);
    });

    test('ingresarComoInvitado asigna usuario invitado al notifier', () async {
      await auth.ingresarComoInvitado();

      expect(auth.estaAutenticado, isTrue);
      expect(auth.usuarioActual?.esInvitado, isTrue);
      expect(auth.usuarioActual?.role, equals('guest'));
    });

    test('ingresarDemo asigna usuario de prueba con credenciales', () async {
      final resultado = await auth.ingresarDemo();

      expect(resultado.exitoso, isTrue);
      expect(auth.estaAutenticado, isTrue);
      expect(auth.usuarioActual?.email, equals('turista@ikatravel.pe'));
      expect(auth.usuarioActual?.esInvitado, isFalse);
    });

    test('login con credenciales locales/fallback inicia sesión', () async {
      final resultado = await auth.login('viajero@test.com', 'claveSegura123');

      expect(resultado.exitoso, isTrue);
      expect(auth.estaAutenticado, isTrue);
      expect(auth.usuarioActual?.email, equals('viajero@test.com'));
    });

    test('login con contraseña muy corta falla con mensaje amigable', () async {
      final resultado = await auth.login('viajero@test.com', '123');

      expect(resultado.exitoso, isFalse);
      expect(resultado.mensaje, contains('al menos 6 caracteres'));
      expect(auth.estaAutenticado, isFalse);
    });

    test('registrar crea nuevo usuario y lo autentica', () async {
      final resultado = await auth.registrar(
        email: 'nuevo@ikatravel.pe',
        password: 'Password2026*',
        fullName: 'Rodrigo Mendoza',
        phone: '+51 912 345 678',
      );

      expect(resultado.exitoso, isTrue);
      expect(auth.estaAutenticado, isTrue);
      expect(auth.usuarioActual?.fullName, equals('Rodrigo Mendoza'));
      expect(auth.usuarioActual?.email, equals('nuevo@ikatravel.pe'));
    });

    test('cerrarSesion elimina el usuario activo', () async {
      await auth.ingresarComoInvitado();
      expect(auth.estaAutenticado, isTrue);

      await auth.cerrarSesion();
      expect(auth.estaAutenticado, isFalse);
      expect(auth.usuarioActual, isNull);
    });
  });
}
