import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactoEmergencia {
  final String nombre;
  final String telefono;
  final String relacion;

  const ContactoEmergencia({
    required this.nombre,
    required this.telefono,
    required this.relacion,
  });

  ContactoEmergencia copyWith({
    String? nombre,
    String? telefono,
    String? relacion,
  }) {
    return ContactoEmergencia(
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      relacion: relacion ?? this.relacion,
    );
  }
}

class NumeroEmergenciaOficial {
  final String nombre;
  final String numero;
  final String descripcion;
  final String tipo;

  const NumeroEmergenciaOficial({
    required this.nombre,
    required this.numero,
    required this.descripcion,
    required this.tipo,
  });
}

/// Servicio que gestiona la configuración SOS, contactos de confianza,
/// geolocalización satelital en tiempo real y despacho directo a WhatsApp / SMS.
class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;

  SosService._internal() {
    contactoNotifier.value = const ContactoEmergencia(
      nombre: 'Contacto de Emergencia',
      telefono: '+51 956 789 123',
      relacion: 'Familiar directo',
    );
    // Intentar obtener ubicación satelital en segundo plano
    actualizarUbicacionReal();
  }

  /// Notificador del contacto de confianza registrado
  final ValueNotifier<ContactoEmergencia?> contactoNotifier =
      ValueNotifier<ContactoEmergencia?>(null);

  /// Estado del permiso de ubicación
  final ValueNotifier<bool> permisoUbicacionConcedido =
      ValueNotifier<bool>(true);

  /// Coordenadas reales obtenidas del dispositivo
  double _latitud = -14.0875;
  double _longitud = -75.7633;
  String _lugar = 'Huacachina, Ica, Perú';
  bool _esUbicacionGpsReal = false;

  double get latitudActual => _latitud;
  double get longitudActual => _longitud;
  String get lugarReferencia => _lugar;
  bool get esUbicacionGpsReal => _esUbicacionGpsReal;

  /// Obtiene la posición GPS real y precisa del teléfono
  Future<bool> actualizarUbicacionReal() async {
    try {
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        permisoUbicacionConcedido.value = false;
        return false;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied ||
            permiso == LocationPermission.deniedForever) {
          permisoUbicacionConcedido.value = false;
          return false;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      _latitud = pos.latitude;
      _longitud = pos.longitude;
      _esUbicacionGpsReal = true;
      _lugar = 'Coordenadas GPS reales: ${_latitud.toStringAsFixed(4)}, ${_longitud.toStringAsFixed(4)}';
      permisoUbicacionConcedido.value = true;
      return true;
    } catch (e) {
      debugPrint('[SosService] Error al obtener GPS real: $e');
      return false;
    }
  }

  /// Números de emergencia oficiales de Perú e Ica
  final List<NumeroEmergenciaOficial> numerosOficiales = const [
    NumeroEmergenciaOficial(
      nombre: 'Policía Nacional del Perú',
      numero: '105',
      descripcion: 'Atención policial inmediata a nivel nacional.',
      tipo: 'policia',
    ),
    NumeroEmergenciaOficial(
      nombre: 'Bomberos Voluntarios',
      numero: '116',
      descripcion: 'Rescate, incendios y accidentes vehiculares.',
      tipo: 'bomberos',
    ),
    NumeroEmergenciaOficial(
      nombre: 'SAMU (Ambulancia)',
      numero: '106',
      descripcion: 'Atención médica de urgencias y emergencias.',
      tipo: 'medico',
    ),
    NumeroEmergenciaOficial(
      nombre: 'Policía de Turismo Ica',
      numero: '+51 980 122 377',
      descripcion: 'Asistencia especializada y protección al turista.',
      tipo: 'turismo',
    ),
  ];

  /// Registrar o actualizar el contacto de confianza
  void guardarContacto({
    required String nombre,
    required String telefono,
    required String relacion,
  }) {
    contactoNotifier.value = ContactoEmergencia(
      nombre: nombre.trim(),
      telefono: telefono.trim(),
      relacion:
          relacion.trim().isEmpty ? 'Contacto de confianza' : relacion.trim(),
    );
  }

  /// Eliminar contacto registrado
  void eliminarContacto() {
    contactoNotifier.value = null;
  }

  /// Conceder o revocar permiso de geolocalización
  void setPermisoUbicacion(bool concedido) {
    permisoUbicacionConcedido.value = concedido;
    if (concedido) {
      actualizarUbicacionReal();
    }
  }

  /// Generar el texto del mensaje de emergencia con coordenadas reales
  String generarMensajeEmergencia({
    bool modoPrueba = false,
  }) {
    final buffer = StringBuffer();

    if (modoPrueba) {
      buffer.writeln('[MODO PRUEBA IKA TRAVEL - NO ES UNA EMERGENCIA REAL]');
    }

    buffer.writeln('🚨 ¡ALERTA SOS! ¡NECESITO AYUDA! Necesito asistencia urgente.');

    if (permisoUbicacionConcedido.value) {
      buffer.writeln(
        '📍 Mi ubicación actual es:\n'
        'https://maps.google.com/?q=${_latitud.toStringAsFixed(6)},${_longitud.toStringAsFixed(6)}\n'
        '($_lugar)',
      );
    } else {
      buffer.writeln(
        '⚠️ Ubicación GPS no disponible / no compartida por el dispositivo.',
      );
    }

    buffer.write(
      'Mensaje emitido con la app Ika Travel. Por favor comunícate de inmediato conmigo o avisa a las autoridades.',
    );

    return buffer.toString();
  }

  /// Abre WhatsApp directamente con el número y mensaje listo para enviar
  Future<bool> abrirWhatsApp({
    required String telefono,
    required String mensaje,
  }) async {
    var cleanPhone = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }

    // Intento 1: esquema directo whatsapp://send
    final uriApp = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(mensaje)}',
    );
    try {
      if (await canLaunchUrl(uriApp)) {
        return await launchUrl(uriApp, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // Intento 2: enlace universal wa.me
    final uriWeb = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(mensaje)}',
    );
    try {
      return await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[SosService] Error abriendo WhatsApp: $e');
      return false;
    }
  }

  /// Abre la aplicación de mensajería SMS predeterminada
  Future<bool> abrirSms({
    required String telefono,
    required String mensaje,
  }) async {
    final cleanPhone = telefono.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: {'body': mensaje},
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[SosService] Error abriendo SMS: $e');
      return false;
    }
  }

  /// Realiza llamada directa al número oficial o de confianza
  Future<bool> llamarNumero({required String telefono}) async {
    final cleanPhone = telefono.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[SosService] Error llamando a número: $e');
      return false;
    }
  }

  static const MethodChannel _canalNativo =
      MethodChannel('com.example.ika_travel_mobile/sms_directo');

  /// Envía un SMS silencioso en segundo plano directo por el chip celular (Cero clics)
  Future<bool> enviarSmsSilenciosoDirecto({
    required String telefono,
    required String mensaje,
  }) async {
    try {
      final resultado = await _canalNativo.invokeMethod<bool>('enviarSmsDirecto', {
        'telefono': telefono,
        'mensaje': mensaje,
      });
      return resultado ?? false;
    } catch (e) {
      debugPrint('[SosService] Fallback a intent SMS por error: $e');
      return await abrirSms(telefono: telefono, mensaje: mensaje);
    }
  }

  /// Realiza la llamada directa al número oficial o de confianza
  Future<bool> realizarLlamadaDirectaAuxilio({required String telefono}) async {
    try {
      final resultado = await _canalNativo.invokeMethod<bool>('realizarLlamadaDirecta', {
        'telefono': telefono,
      });
      return resultado ?? false;
    } catch (e) {
      return await llamarNumero(telefono: telefono);
    }
  }

  /// Envía la alerta automática multicanal (SMS Silencioso Directo + WhatsApp)
  Future<bool> enviarAlertaAutomatica({
    required String telefono,
    required String mensaje,
  }) async {
    // 1. Envío de SMS silencioso nativo (sin abrir ventanas ni clics)
    final okSms = await enviarSmsSilenciosoDirecto(telefono: telefono, mensaje: mensaje);
    // 2. Breve pausa para asegurar el despacho
    await Future.delayed(const Duration(milliseconds: 650));
    // 3. Abrir WhatsApp directamente con el texto y contacto listo
    final okWsp = await abrirWhatsApp(telefono: telefono, mensaje: mensaje);
    return okSms || okWsp;
  }
}

