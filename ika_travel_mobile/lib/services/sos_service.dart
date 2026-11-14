import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'persistencia_service.dart';

/// Resultado del registro de una alerta SOS en el backend (`sos_reports`).
class ResultadoRegistroSos {
  final bool exitoso;
  final String mensaje;
  final String? reportId;
  final String? status;

  const ResultadoRegistroSos({
    required this.exitoso,
    required this.mensaje,
    this.reportId,
    this.status,
  });
}

class ContactoEmergencia {
  final String nombre;
  final String telefono;
  final String relacion;

  const ContactoEmergencia({
    required this.nombre,
    required this.telefono,
    required this.relacion,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'telefono': telefono,
        'relacion': relacion,
      };

  factory ContactoEmergencia.fromJson(Map<String, dynamic> json) =>
      ContactoEmergencia(
        nombre: json['nombre']?.toString() ?? '',
        telefono: json['telefono']?.toString() ?? '',
        relacion: json['relacion']?.toString() ?? 'Familiar directo',
      );

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

  final PersistenciaService _persistencia = PersistenciaService();

  SosService._internal() {
    contactoNotifier.value = const ContactoEmergencia(
      nombre: 'Contacto de Emergencia',
      telefono: '+51 956 789 123',
      relacion: 'Familiar directo',
    );
    _cargarContactoPersistido();
    // Intentar obtener ubicación satelital en segundo plano
    actualizarUbicacionReal();
  }

  Future<void> _cargarContactoPersistido() async {
    try {
      final json = await _persistencia.leerJson('contacto_emergencia_sos');
      if (json != null) {
        contactoNotifier.value = ContactoEmergencia.fromJson(json);
      }
    } catch (e) {
      debugPrint('[SosService] Error al cargar contacto guardado: $e');
    }
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
    final contacto = ContactoEmergencia(
      nombre: nombre.trim(),
      telefono: telefono.trim(),
      relacion:
          relacion.trim().isEmpty ? 'Contacto de confianza' : relacion.trim(),
    );
    contactoNotifier.value = contacto;
    _persistencia.guardarJson('contacto_emergencia_sos', contacto.toJson());
  }

  /// Eliminar contacto registrado
  void eliminarContacto() {
    contactoNotifier.value = null;
    _persistencia.eliminar('contacto_emergencia_sos');
  }

  /// Conceder o revocar permiso de geolocalización
  void setPermisoUbicacion(bool concedido) {
    permisoUbicacionConcedido.value = concedido;
    if (concedido) {
      actualizarUbicacionReal();
    }
  }

  /// Generar el texto del mensaje de emergencia con coordenadas reales y remitente
  String generarMensajeEmergencia({
    bool modoPrueba = false,
    String? nombreUsuario,
    String? telefonoUsuario,
    String? motivoAccidente,
  }) {
    final buffer = StringBuffer();

    if (modoPrueba) {
      buffer.writeln('[MODO PRUEBA IKA TRAVEL - NO ES UNA EMERGENCIA REAL]');
      buffer.writeln();
    }

    final nombre = (nombreUsuario != null && nombreUsuario.trim().isNotEmpty)
        ? nombreUsuario.trim()
        : 'el usuario registrado';

    final accidente = (motivoAccidente != null && motivoAccidente.trim().isNotEmpty)
        ? motivoAccidente.trim()
        : 'un accidente en mi recorrido';

    buffer.writeln('Hola soy $nombre y te envio este mensaje porque he tenido este accidente: $accidente.');
    buffer.writeln();
    buffer.writeln('🚨 ¡ALERTA SOS! ¡NECESITO AYUDA! Necesito asistencia urgente.');
    buffer.writeln();

    if (telefonoUsuario != null && telefonoUsuario.trim().isNotEmpty) {
      buffer.writeln('📱 Mi número de contacto es: ${telefonoUsuario.trim()}');
      buffer.writeln();
    }

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

    buffer.writeln();
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

  /// Registra el reporte de emergencia y sus notificaciones en la base de datos del backend (Corrección N° 7 / RF-05)
  Future<bool> registrarEmergenciaEnBackend({
    required double latitud,
    required double longitud,
    required String descripcion,
    ContactoEmergencia? contacto,
  }) async {
    final usuario = AuthService().usuarioActual;
    final token = usuario?.token ?? '';
    final url = Uri.parse(ApiConfig.emergencySos);

    final bodyMap = <String, dynamic>{
      'latitude': latitud,
      'longitude': longitud,
      'description': descripcion.trim(),
      if (contacto != null) ...{
        'contact_name': contacto.nombre.trim(),
        'contact_phone': contacto.telefono.trim(),
      },
    };

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Idempotency-Key': 'sos_${DateTime.now().millisecondsSinceEpoch}_${usuario?.id ?? "anon"}',
    };

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(bodyMap))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('[SosService] Emergencia y notificaciones guardadas en BD con éxito (HTTP ${response.statusCode})');
        return true;
      } else {
        debugPrint('[SosService] Error al guardar emergencia en backend (HTTP ${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[SosService] Excepción al registrar emergencia en backend: $e');
      return false;
    }
  }

  /// Envía la alerta automática multicanal (SMS Silencioso Directo + WhatsApp + Backend / BD)
  Future<bool> enviarAlertaAutomatica({
    required String telefono,
    required String mensaje,
    ContactoEmergencia? contacto,
    String? descripcionAccidente,
  }) async {
    // 0. Registrar reporte SOS y notificaciones en la BD PostgreSQL (Corrección N° 7)
    registrarEmergenciaEnBackend(
      latitud: _latitud,
      longitud: _longitud,
      descripcion: descripcionAccidente ?? mensaje,
      contacto: contacto ?? contactoNotifier.value,
    );

    // 1. Envío de SMS silencioso nativo (sin abrir ventanas ni clics)
    final okSms = await enviarSmsSilenciosoDirecto(telefono: telefono, mensaje: mensaje);
    // 2. Breve pausa para asegurar el despacho
    await Future.delayed(const Duration(milliseconds: 650));
    // 3. Abrir WhatsApp directamente con el texto y contacto listo
    final okWsp = await abrirWhatsApp(telefono: telefono, mensaje: mensaje);
    return okSms || okWsp;
  }

  /// Registra la alerta/alerta SOS en el backend (`POST /api/v1/emergency/sos`)
  /// para persistirla en la tabla `sos_reports` (Corrección N.º 10).
  ///
  /// - Requiere usuario autenticado (JWT); devuelve `exitoso=false` como invitado.
  /// - Envía coordenadas GPS reales (o las últimas conocidas) y el mensaje de
  ///   alerta como `description`.
  /// - Usa `Idempotency-Key` para no duplicar reportes si el usuario reintentas.
  /// - Nunca lanza excepciones: en una emergencia el fallo de red no debe
  ///   romper el flujo de despacho por SMS/WhatsApp.
  Future<ResultadoRegistroSos> registrarAlertaSos({
    String? mensajeAlerta,
    String? motivo,
    ContactoEmergencia? contacto,
  }) async {
    final usuario = AuthService().usuarioActual;
    if (usuario == null || usuario.esInvitado) {
      return const ResultadoRegistroSos(
        exitoso: false,
        mensaje: 'Debes iniciar sesión para registrar la alerta SOS en el sistema.',
      );
    }

    // Asegurar coordenadas lo más recientes posible antes de reportar.
    if (permisoUbicacionConcedido.value) {
      await actualizarUbicacionReal();
    }

    final token = usuario.token ?? '';
    final textoAlerta = (motivo != null && motivo.trim().isNotEmpty)
        ? motivo.trim()
        : (mensajeAlerta ?? '').trim();
    final contactoActual = contacto ?? contactoNotifier.value;
    final body = <String, dynamic>{
      'latitude': _latitud,
      'longitude': _longitud,
      if (textoAlerta.isNotEmpty)
        'description':
            textoAlerta.length > 2000 ? textoAlerta.substring(0, 2000) : textoAlerta,
      if (contactoActual != null) ...{
        'contact_name': contactoActual.nombre.trim(),
        'contact_phone': contactoActual.telefono.trim(),
      },
    };

    try {
      final url = Uri.parse(ApiConfig.emergencySos);
      // La clave debe cumplir el patrón del backend:^[A-Za-z0-9_-]{8,64}$.
      var claveIdempotencia =
          'sos_${DateTime.now().millisecondsSinceEpoch}_${usuario.id}';
      if (claveIdempotencia.length > 64) {
        claveIdempotencia = claveIdempotencia.substring(0, 64);
      }
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              ...ApiConfig.defaultHeaders,
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              'Idempotency-Key': claveIdempotencia,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        debugPrint('[SosService] Alerta SOS registrada: ${data['id']}');
        return ResultadoRegistroSos(
          exitoso: true,
          mensaje: 'Alerta SOS registrada en el sistema (estado: ${data['status'] ?? 'pending'}).',
          reportId: data['id']?.toString(),
          status: data['status']?.toString(),
        );
      }
      if (response.statusCode == 401) {
        return const ResultadoRegistroSos(
          exitoso: false,
          mensaje: 'Tu sesión ha expirado: la alerta no se registró en el sistema.',
        );
      }
      if (response.statusCode == 400 || response.statusCode == 422) {
        return const ResultadoRegistroSos(
          exitoso: false,
          mensaje: 'Sin coordenadas GPS válidas: la alerta no se registró (RN-04).',
        );
      }
      debugPrint('[SosService] Error SOS ${response.statusCode}: ${response.body}');
      return ResultadoRegistroSos(
        exitoso: false,
        mensaje: 'El servidor no registró la alerta (código ${response.statusCode}).',
      );
    } on TimeoutException catch (e) {
      debugPrint('[SosService] Timeout registrando alerta SOS: $e');
      return const ResultadoRegistroSos(
        exitoso: false,
        mensaje: 'Sin conexión con la central: la alerta no se registró en el sistema.',
      );
    } catch (e) {
      debugPrint('[SosService] Error de red registrando alerta SOS: $e');
      return const ResultadoRegistroSos(
        exitoso: false,
        mensaje: 'No hubo conexión con la central de emergencias ($e).',
      );
    }
  }
}

