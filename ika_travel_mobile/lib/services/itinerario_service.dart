import 'package:flutter/foundation.dart';
import '../models/itinerario_modelo.dart';
import 'osrm_service.dart';
import 'persistencia_service.dart';

/// Clave de almacenamiento para el itinerario activo
const _claveItinerario = 'itinerario_activo';

/// Estado de cálculo de rutas
enum EstadoCalculo { inactivo, calculando, completado, errorParcial }

/// Servicio global del planificador de viajes.
///
/// Gestiona el itinerario activo, la reordenación de destinos,
/// el cálculo de rutas por tramos y la persistencia entre sesiones.
///
/// Arquitectura: singleton reactivo con [ValueNotifier].
class ItinerarioService {
  static final ItinerarioService _instancia = ItinerarioService._();
  factory ItinerarioService() => _instancia;
  ItinerarioService._();

  final _osrm = OsrmService();
  final _persistencia = PersistenciaService();

  /// Itinerario activo (puede ser null si aún no se creó ninguno)
  final ValueNotifier<ItinerarioViaje?> itinerarioNotifier =
      ValueNotifier(null);

  /// Estado actual del cálculo de rutas
  final ValueNotifier<EstadoCalculo> estadoCalculoNotifier =
      ValueNotifier(EstadoCalculo.inactivo);

  /// Mensaje de progreso durante el cálculo
  final ValueNotifier<String> mensajeCalculoNotifier =
      ValueNotifier('');

  ItinerarioViaje? get itinerario => itinerarioNotifier.value;

  // ─────────────────────────────────────────────────
  // Ciclo de vida del itinerario
  // ─────────────────────────────────────────────────

  /// Crea un nuevo itinerario vacío con el origen predeterminado
  void crearNuevoItinerario() {
    itinerarioNotifier.value = ItinerarioViaje.nuevo();
    estadoCalculoNotifier.value = EstadoCalculo.inactivo;
  }

  /// Carga el itinerario guardado. Si no existe, crea uno nuevo.
  Future<void> cargarItinerario() async {
    try {
      final json = await _persistencia.leerJson(_claveItinerario);
      if (json != null) {
        itinerarioNotifier.value = ItinerarioViaje.fromJson(json);
      } else {
        crearNuevoItinerario();
      }
    } catch (e) {
      debugPrint('[ItinerarioService] Error al cargar: $e');
      crearNuevoItinerario();
    }
  }

  /// Guarda el itinerario activo en la capa de persistencia
  Future<void> guardarItinerario() async {
    final it = itinerarioNotifier.value;
    if (it == null) return;
    try {
      await _persistencia.guardarJson(_claveItinerario, it.toJson());
    } catch (e) {
      debugPrint('[ItinerarioService] Error al guardar: $e');
    }
  }

  /// Cambia el título del itinerario
  void cambiarTitulo(String nuevoTitulo) {
    final it = itinerarioNotifier.value;
    if (it == null) return;
    itinerarioNotifier.value = it.copyWith(titulo: nuevoTitulo);
  }

  // ─────────────────────────────────────────────────
  // Gestión del origen
  // ─────────────────────────────────────────────────

  /// Establece el punto de origen del itinerario
  void establecerOrigen(PuntoItinerario origen) {
    final it = itinerarioNotifier.value;
    if (it == null) return;
    final nuevosPuntos = [origen, ...it.destinos];
    itinerarioNotifier.value = it.copyWith(
      puntos: nuevosPuntos,
      tramos: [], // rutas invalidadas
    );
    estadoCalculoNotifier.value = EstadoCalculo.inactivo;
  }

  // ─────────────────────────────────────────────────
  // Gestión de destinos
  // ─────────────────────────────────────────────────

  /// Agrega un destino al final del itinerario
  void agregarDestino(PuntoItinerario destino) {
    final it = itinerarioNotifier.value;
    if (it == null) return;
    // No permitir duplicados
    if (it.puntos.any((p) => p.id == destino.id)) return;
    itinerarioNotifier.value = it.copyWith(
      puntos: [...it.puntos, destino],
      tramos: [],
    );
    estadoCalculoNotifier.value = EstadoCalculo.inactivo;
  }

  /// Elimina un destino por ID (el origen no puede eliminarse desde aquí)
  void eliminarDestino(String id) {
    final it = itinerarioNotifier.value;
    if (it == null) return;
    // puntos[0] es el origen; solo eliminamos si index > 0
    final nuevosPuntos = it.puntos.where((p) => p.id != id).toList();
    if (nuevosPuntos.length == it.puntos.length) return; // no encontrado
    itinerarioNotifier.value = it.copyWith(
      puntos: nuevosPuntos,
      tramos: [],
    );
    estadoCalculoNotifier.value = EstadoCalculo.inactivo;
  }

  /// Reordena destinos (no afecta al origen en posición 0).
  ///
  /// [indiceAntiguo] y [indiceNuevo] son índices dentro de [destinos]
  /// (no incluyen el origen).
  void reordenarDestinos(int indiceAntiguo, int indiceNuevo) {
    final it = itinerarioNotifier.value;
    if (it == null) return;
    final destinos = [...it.destinos];
    if (indiceAntiguo < 0 ||
        indiceNuevo < 0 ||
        indiceAntiguo >= destinos.length ||
        indiceNuevo >= destinos.length) {
      return;
    }

    final item = destinos.removeAt(indiceAntiguo);
    destinos.insert(indiceNuevo, item);
    itinerarioNotifier.value = it.copyWith(
      puntos: [it.origen!, ...destinos],
      tramos: [],
    );
    estadoCalculoNotifier.value = EstadoCalculo.inactivo;
  }

  // ─────────────────────────────────────────────────
  // Cálculo de rutas
  // ─────────────────────────────────────────────────

  /// Calcula todos los tramos del itinerario consultando OSRM.
  /// Los tramos con error usarán ruta simulada (línea recta).
  Future<void> calcularRutas() async {
    final it = itinerarioNotifier.value;
    if (it == null || it.puntos.length < 2) return;

    estadoCalculoNotifier.value = EstadoCalculo.calculando;
    mensajeCalculoNotifier.value = 'Conectando con OSRM…';

    final tramos = <TramoRuta>[];
    bool haySimulados = false;

    for (int i = 0; i < it.puntos.length - 1; i++) {
      final origen = it.puntos[i];
      final destino = it.puntos[i + 1];
      mensajeCalculoNotifier.value =
          'Calculando tramo ${i + 1} de ${it.puntos.length - 1}…';

      final tramo = await _osrm.calcularTramo(
        origen: origen,
        destino: destino,
        color: colorParaTramo(i),
      );
      tramos.add(tramo);
      if (tramo.esSimulado) haySimulados = true;
    }

    itinerarioNotifier.value = it.copyWith(tramos: tramos);
    estadoCalculoNotifier.value = haySimulados
        ? EstadoCalculo.errorParcial
        : EstadoCalculo.completado;
    mensajeCalculoNotifier.value = '';

    // Persistir automáticamente al calcular
    await guardarItinerario();
  }
}
