import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:flutter/foundation.dart';

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
/// permisos de ubicación para emergencias y generación de mensajes.
class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;

  SosService._internal() {
    // Contacto inicial demostrativo editable
    contactoNotifier.value = const ContactoEmergencia(
      nombre: 'Contacto de Emergencia',
      telefono: '+51 956 789 123',
      relacion: 'Familiar directo',
    );
  }

  /// Notificador del contacto de confianza registrado
  final ValueNotifier<ContactoEmergencia?> contactoNotifier =
      ValueNotifier<ContactoEmergencia?>(null);

  /// Estado del permiso de ubicación simulado/concedido
  final ValueNotifier<bool> permisoUbicacionConcedido =
      ValueNotifier<bool>(true);

  /// Ubicación de referencia en Ica (Huacachina / Dunas)
  double get latitudActual => -14.0875;
  double get longitudActual => -75.7626;
  String get lugarReferencia => 'Oasis de Huacachina, Ica, Perú';


  /// Carga números de emergencia oficiales desde el backend FastAPI (/api/v1/emergency/contacts)
  /// Si el servidor no responde, conserva la lista local predeterminada.
  Future<void> sincronizarContactosOficiales() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.emergencyContacts), headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data.isNotEmpty) {
          _numerosOficialesDinamicos = data.map((item) {
            return NumeroEmergenciaOficial(
              nombre: item['name'] ?? '',
              numero: item['phone'] ?? '',
              descripcion: item['description'] ?? '',
              tipo: item['category'] ?? 'general',
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[SosService] Usando directorio de emergencia local: $e');
    }
  }

  List<NumeroEmergenciaOficial>? _numerosOficialesDinamicos;

  /// Números de emergencia oficiales de Perú e Ica
  List<NumeroEmergenciaOficial> get numerosOficiales => _numerosOficialesDinamicos ?? _numerosOficialesDefecto;

  static const List<NumeroEmergenciaOficial> _numerosOficialesDefecto = [
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
      relacion: relacion.trim().isEmpty ? 'Contacto de confianza' : relacion.trim(),
    );
  }

  /// Eliminar contacto registrado
  void eliminarContacto() {
    contactoNotifier.value = null;
  }

  /// Conceder o revocar permiso de geolocalización
  void setPermisoUbicacion(bool concedido) {
    permisoUbicacionConcedido.value = concedido;
  }

  /// Generar el texto del mensaje de emergencia con o sin ubicación
  String generarMensajeEmergencia({
    bool modoPrueba = false,
  }) {
    final buffer = StringBuffer();

    if (modoPrueba) {
      buffer.writeln('🧪 [MODO PRUEBA IKA TRAVEL - NO ES UNA EMERGENCIA REAL]');
    }

    buffer.writeln('🚨 ¡NECESITO AYUDA! Estoy en una situación de emergencia.');

    if (permisoUbicacionConcedido.value) {
      buffer.writeln(
        '📍 Mi ubicación aproximada es:\n'
        'https://maps.google.com/?q=$latitudActual,$longitudActual\n'
        '($lugarReferencia)',
      );
    } else {
      buffer.writeln(
        '⚠️ Ubicación GPS no disponible (permiso no concedido en el dispositivo).',
      );
    }

    buffer.write(
      'Enviado desde la app Ika Travel. Por favor intenta comunicarte conmigo o contacta a las autoridades locales de Ica.',
    );

    return buffer.toString();
  }

  /// Prepara el enlace URI para abrir la app de mensajería SMS
  Uri generarUriSms(String telefono, String mensaje) {
    final cleanPhone = telefono.replaceAll(RegExp(r'\s+'), '');
    return Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: {'body': mensaje},
    );
  }

  /// Enlace directo para WhatsApp Web o app móvil
  Uri generarUriWhatsApp(String telefono, String mensaje) {
    var cleanPhone = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }
    return Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(mensaje)}',
    );
  }
}
