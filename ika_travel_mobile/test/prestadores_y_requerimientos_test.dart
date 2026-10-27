import 'package:flutter_test/flutter_test.dart';
import 'package:ika_travel_mobile/models/prestador_servicio_modelo.dart';
import 'package:ika_travel_mobile/models/usuario_modelo.dart';
import 'package:ika_travel_mobile/models/weather_model.dart';
import 'package:ika_travel_mobile/services/api_service.dart';
import 'package:ika_travel_mobile/services/auth_service.dart';
import 'package:ika_travel_mobile/services/incidencias_service.dart';
import 'package:ika_travel_mobile/services/prestadores_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RF-01: Autenticación, Sesión y Preferencias del Turista', () {
    final auth = AuthService();

    test('Usuario invitado es diferenciado de usuario registrado', () {
      final guest = UsuarioModelo.invitado();
      expect(guest.esInvitado, isTrue);
      expect(guest.role, equals('guest'));

      final registered = UsuarioModelo.demo();
      expect(registered.esInvitado, isFalse);
      expect(registered.email, equals('turista@ikatravel.pe'));
    });

    test('actualizarPreferencias persiste nuevas categorías de interés', () async {
      await auth.ingresarDemo();
      expect(auth.usuarioActual, isNotNull);

      final nuevas = ['aventura', 'vino_pisco', 'sol_playa'];
      final exito = await auth.actualizarPreferencias(nuevas);

      expect(exito, isTrue);
      expect(auth.usuarioActual?.preferences, equals(nuevas));
    });
  });

  group('RF-02: Exploración de Atractivos y Filtros de Categoría', () {
    test('ApiService retorna catálogo completo con categorías turísticas', () async {
      final api = ApiService();
      final atractivos = await api.obtenerActividades();

      expect(atractivos, isNotEmpty);
      expect(atractivos.first.containsKey('titulo'), isTrue);
      expect(atractivos.first.containsKey('categoria'), isTrue);
      expect(atractivos.first.containsKey('imagenes_detalle'), isTrue);

      final categorias = atractivos.map((a) => a['categoria'].toString()).toSet();
      expect(categorias.contains('Aventura') || categorias.contains('Naturaleza'), isTrue);
    });
  });

  group('RF-03 & RN-01: Búsqueda de Prestadores Formalizados DIRCETUR', () {
    test('PrestadorServicioModel cumple la regla RN-01 (is_validated)', () {
      const formal = PrestadorServicioModel(
        id: 'ag-1',
        name: 'Agencia Oficial Ica',
        isValidated: true,
        dirceturRegistryNumber: 'DIRCETUR-001',
      );
      expect(formal.esFormalValidado, isTrue);

      const noFormal = PrestadorServicioModel(
        id: 'ag-2',
        name: 'Operador No Empadronado',
        isValidated: false,
      );
      expect(noFormal.esFormalValidado, isFalse);
    });

    test('PrestadoresService retorna exclusivamente prestadores validados por DIRCETUR', () async {
      final service = PrestadoresService();
      final prestadores = await service.buscarPrestadores();

      expect(prestadores, isNotEmpty);
      for (final p in prestadores) {
        expect(p.esFormalValidado, isTrue, reason: 'RN-01: Todo prestador debe estar validado por DIRCETUR');
        expect(p.dirceturRegistryNumber, isNotNull);
      }
    });

    test('Búsqueda por palabra clave filtra prestadores y tours correspondientes', () async {
      final service = PrestadoresService();
      final resultados = await service.buscarPrestadores(query: 'Buggy');

      expect(resultados, isNotEmpty);
      final coincide = resultados.any((p) =>
          p.name.toLowerCase().contains('buggy') ||
          p.tours.any((t) => t.name.toLowerCase().contains('buggy')));
      expect(coincide, isTrue);
    });
  });

  group('RF-05 & RN-04: Emisión de Incidencias y SOS', () {
    test('IncidenciasService rechaza envío si el turista no ha iniciado sesión', () async {
      final auth = AuthService();
      await auth.cerrarSesion();
      expect(auth.estaAutenticado, isFalse);

      final incidencias = IncidenciasService();
      final res = await incidencias.enviarReporte(
        tipoIncidente: 'informal_service',
        titulo: 'Operador sin licencia',
        descripcion: 'Detalle de prueba sobre operador en dunas de Huacachina.',
      );

      expect(res.exitoso, isFalse);
      expect(res.mensaje, contains('Debes iniciar sesión'));
    });

    test('IncidenciasService rechaza envío en modo invitado', () async {
      final auth = AuthService();
      await auth.ingresarComoInvitado();
      expect(auth.usuarioActual?.esInvitado, isTrue);

      final incidencias = IncidenciasService();
      final res = await incidencias.enviarReporte(
        tipoIncidente: 'route_obstruction',
        titulo: 'Vía bloqueada',
        descripcion: 'Detalle de obstrucción en acceso.',
      );

      expect(res.exitoso, isFalse);
      expect(res.mensaje, contains('Debes iniciar sesión con una cuenta registrada'));
    });
  });

  group('RF-06 & RN-03: Información Meteorológica y Vigencia de 6 horas', () {
    test('ClimaActualModel reconoce datos como vigentes si tienen menos de 6 horas', () {
      final climaReciente = ClimaActualModel.fromJson({
        'temperatura_actual': 27.5,
        'sensacion_termica': 28.0,
        'probabilidad_precipitacion': 0.0,
        'humedad': 45.0,
        'velocidad_viento': 15.0,
        'indice_uv': 8.0,
        'descripcion_clima': 'Despejado',
        'visibilidad': 10.0,
        'destino': 'Ica',
        'fecha_hora_pronostico': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      });

      expect(climaReciente.esVigente, isTrue);
    });

    test('ClimaActualModel marca datos como no vigentes si superan 6 horas (RN-03)', () {
      final climaDesactualizado = ClimaActualModel.fromJson({
        'temperatura_actual': 22.0,
        'sensacion_termica': 22.0,
        'probabilidad_precipitacion': 0.0,
        'humedad': 55.0,
        'velocidad_viento': 10.0,
        'indice_uv': 4.0,
        'descripcion_clima': 'Nublado',
        'visibilidad': 8.0,
        'destino': 'Ica',
        'fecha_hora_pronostico': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
      });

      expect(climaDesactualizado.esVigente, isFalse);
    });

    test('ClimaActualModel no asume vigencia si no hay timestamp', () {
      final climaSinFecha = ClimaActualModel.fromJson({
        'temperatura_actual': 25.0,
        'sensacion_termica': 25.0,
        'probabilidad_precipitacion': 0.0,
        'humedad': 50.0,
        'velocidad_viento': 12.0,
        'indice_uv': 5.0,
        'descripcion_clima': 'Soleado',
        'visibilidad': 10.0,
        'destino': 'Ica',
      });

      expect(climaSinFecha.esVigente, isFalse);
    });
  });
}
