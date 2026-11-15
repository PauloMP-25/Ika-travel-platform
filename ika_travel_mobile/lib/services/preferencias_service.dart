import 'package:flutter/foundation.dart';
import 'persistencia_service.dart';

/// Guarda y expone las preferencias de viaje del usuario (gustos, estilo,
/// presupuesto y compañía) para que las recomendaciones de la IA se adapten
/// a su perfil. Se persisten localmente con [PersistenciaService].
class PreferenciasService {
  static final PreferenciasService _instancia = PreferenciasService._();
  factory PreferenciasService() => _instancia;
  PreferenciasService._();

  static const String _clave = 'preferencias_usuario';

  final PersistenciaService _persistencia = PersistenciaService();

  /// Notifica cuando cambian las preferencias (para refrescar recomendaciones).
  final ValueNotifier<bool> cambios = ValueNotifier<bool>(false);

  List<String> intereses = [];
  String estilo = ''; // Tranquilo / Equilibrado / Aventurero
  String presupuesto = ''; // Económico / Medio / Premium
  String compania = ''; // Solo / Pareja / Familia / Amigos
  bool _completado = false;

  bool get yaCompletado => _completado;

  /// Carga las preferencias guardadas. Debe llamarse al iniciar la app.
  Future<void> cargar() async {
    final json = await _persistencia.leerJson(_clave);
    if (json == null) return;
    intereses = (json['intereses'] as List?)?.cast<String>() ?? [];
    estilo = json['estilo'] as String? ?? '';
    presupuesto = json['presupuesto'] as String? ?? '';
    compania = json['compania'] as String? ?? '';
    _completado = json['completado'] as bool? ?? false;
  }

  /// Guarda las preferencias del usuario y marca el cuestionario como resuelto.
  Future<void> guardar({
    required List<String> intereses,
    required String estilo,
    required String presupuesto,
    required String compania,
  }) async {
    this.intereses = intereses;
    this.estilo = estilo;
    this.presupuesto = presupuesto;
    this.compania = compania;
    _completado = true;
    await _persistencia.guardarJson(_clave, {
      'intereses': intereses,
      'estilo': estilo,
      'presupuesto': presupuesto,
      'compania': compania,
      'completado': true,
    });
    cambios.value = !cambios.value;
  }

  /// Marca el cuestionario como visto sin registrar gustos (botón "Omitir").
  Future<void> omitir() async {
    _completado = true;
    await _persistencia.guardarJson(_clave, {
      'intereses': intereses,
      'estilo': estilo,
      'presupuesto': presupuesto,
      'compania': compania,
      'completado': true,
    });
  }

  /// Puente entre los gustos que elige el usuario en el modal de bienvenida
  /// (texto natural, para la IA) y las claves de preferencia que guarda el
  /// perfil del usuario (`usuario.preferences`, RF-01).
  ///
  /// Existe para que los dos no se contradigan: antes el modal y el diálogo
  /// de "mis preferencias" guardaban cosas distintas en sitios distintos.
  static const Map<String, String> _interesAClave = {
    'Aventura y adrenalina': 'aventura',
    'Gastronomía y pisco': 'vino_pisco',
    'Cultura e historia': 'cultura',
    'Naturaleza y mar': 'naturaleza',
    'Relax y bienestar': 'sol_playa',
    'Fotografía': 'cultura',
    'Playas': 'sol_playa',
    'Vida nocturna': 'vino_pisco',
  };

  /// Los gustos elegidos, traducidos a las claves del perfil del usuario.
  List<String> get clavesDePerfil {
    final claves = <String>{};
    for (final interes in intereses) {
      final clave = _interesAClave[interes];
      if (clave != null) claves.add(clave);
    }
    return claves.toList();
  }

  /// Rehidrata los gustos a partir de las claves guardadas en el perfil, para
  /// que la IA siga personalizando si el usuario los editó desde Ajustes.
  void sincronizarDesdeClaves(List<String> claves) {
    if (claves.isEmpty) return;
    final etiquetas = <String>{};
    for (final entrada in _interesAClave.entries) {
      if (claves.contains(entrada.value)) etiquetas.add(entrada.key);
    }
    if (etiquetas.isEmpty) return;
    intereses = etiquetas.toList();
    _completado = true;
    cambios.value = !cambios.value;
  }

  /// Resumen en texto natural para inyectar en el prompt de la IA.
  /// Devuelve cadena vacía si el usuario no registró gustos.
  String resumenParaIA() {
    final partes = <String>[];
    if (intereses.isNotEmpty) {
      partes.add('le interesan: ${intereses.join(', ')}');
    }
    if (estilo.isNotEmpty) partes.add('estilo de viaje $estilo');
    if (presupuesto.isNotEmpty) partes.add('presupuesto $presupuesto');
    if (compania.isNotEmpty) partes.add('viaja $compania');
    if (partes.isEmpty) return '';
    return 'Perfil del viajero: ${partes.join('; ')}.';
  }
}
