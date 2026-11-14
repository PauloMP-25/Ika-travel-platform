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
