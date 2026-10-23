import 'package:flutter/material.dart';
import '../models/seguimiento_modelo.dart';
import '../models/horario_modelo.dart';

/// Servicio de Monitoreo y Seguimiento de Destinos Turísticos (Requerimientos 14 y 3)
class SeguimientoService {
  static final SeguimientoService _instancia = SeguimientoService._interno();
  factory SeguimientoService() => _instancia;
  SeguimientoService._interno() {
    _inicializarDestinosMock();
  }

  // Notificador reactivo con los destinos monitoreados
  final ValueNotifier<List<DestinoSeguimiento>> destinosNotifier = ValueNotifier([]);

  void _inicializarDestinosMock() {
    final List<DestinoSeguimiento> mock = [
      // 1. HUACACHINA
      DestinoSeguimiento(
        id: 'huacachina',
        nombre: 'Huacachina',
        region: 'Ica, Desierto Costero',
        imagen: 'assets/images/carrusel_1_huacachina.jpg',
        ultimaActualizacion: DateTime.now().subtract(const Duration(minutes: 18)),
        estadoGeneral: 'Precaución por ráfagas de viento vespertinas',
        temperaturaActual: '28°C',
        vientoActual: '34 km/h (Ráfagas 48 km/h)',
        humedadActual: '38%',
        uvActual: 'Muy Alto (8)',
        horarioAtencion: HorarioAtencion.paraHuacachina(),
        actividadesAptitud: const [
          AptitudActividad(
            actividadTitulo: 'Paseo en bote en la laguna',
            estado: EstadoAptitud.optima,
            detalleClimatico: 'Laguna protegida por el desnivel de las dunas circundantes.',
          ),
          AptitudActividad(
            actividadTitulo: 'Paseo en buggy en las dunas',
            estado: EstadoAptitud.precaucion,
            detalleClimatico: 'Operar con velocidad reducida en circuitos medios y gafas protectoras.',
          ),
          AptitudActividad(
            actividadTitulo: 'Sandboarding en Huacachina',
            estado: EstadoAptitud.noRecomendada,
            detalleClimatico: 'Viento sobre 30 km/h genera tolvaneras y arena en ojos.',
          ),
        ],
        historialCambios: [
          RegistroCambioHistorial(
            id: 'hist_hc_01',
            fechaHora: DateTime.now().subtract(const Duration(minutes: 42)),
            parametroModificado: 'Velocidad de viento',
            valorAnterior: '14 km/h',
            valorActual: '34 km/h',
            alertaIdAsociada: 'alt_huacachina_001',
            resumenImpacto: 'Aceleración súbita de vientos térmicos Paracas.',
          ),
          RegistroCambioHistorial(
            id: 'hist_hc_02',
            fechaHora: DateTime.now().subtract(const Duration(hours: 3, minutes: 15)),
            parametroModificado: 'Temperatura ambiente',
            valorAnterior: '22°C',
            valorActual: '28°C',
            resumenImpacto: 'Pico de temperatura vespertina en el desierto.',
          ),
          RegistroCambioHistorial(
            id: 'hist_hc_03',
            fechaHora: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
            parametroModificado: 'Índice UV',
            valorAnterior: '6 (Moderado)',
            valorActual: '9 (Extremo)',
            resumenImpacto: 'Cielo despejado con alta radiación al mediodía.',
          ),
          RegistroCambioHistorial(
            id: 'hist_hc_04',
            fechaHora: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
            parametroModificado: 'Velocidad de viento',
            valorAnterior: '32 km/h',
            valorActual: '12 km/h',
            alertaIdAsociada: 'alt_buggy_historial_005',
            resumenImpacto: 'Retorno a la calma climática nocturna.',
          ),
        ],
        alertasActivasIds: ['alt_huacachina_001'],
        esMock: true,
      ),

      // 2. PARACAS
      DestinoSeguimiento(
        id: 'paracas',
        nombre: 'Paracas',
        region: 'Pisco - Paracas, Costa Pacífica',
        imagen: 'assets/images/act_ballestas1.jpg',
        ultimaActualizacion: DateTime.now().subtract(const Duration(minutes: 35)),
        estadoGeneral: 'Restricción marítima preventiva en muelle turístico',
        temperaturaActual: '19°C',
        vientoActual: '28 km/h',
        humedadActual: '72%',
        uvActual: 'Extremo (11+)',
        horarioAtencion: HorarioAtencion.paraIslasBallestas(),
        actividadesAptitud: const [
          AptitudActividad(
            actividadTitulo: 'Islas Ballestas',
            estado: EstadoAptitud.suspendida,
            detalleClimatico: 'Oleaje de 2.2 m con alerta de Capitanía de Puerto de Pisco.',
          ),
          AptitudActividad(
            actividadTitulo: 'Reserva Nacional de Paracas (Terrestre)',
            estado: EstadoAptitud.precaucion,
            detalleClimatico: 'Ruta transitable con precaución por radiación solar extrema.',
          ),
          AptitudActividad(
            actividadTitulo: 'Paseo gastronómico en El Chaco',
            estado: EstadoAptitud.optima,
            detalleClimatico: 'Malecón habilitado y servicios gastronómicos funcionando con normalidad.',
          ),
        ],
        historialCambios: [
          RegistroCambioHistorial(
            id: 'hist_pa_01',
            fechaHora: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
            parametroModificado: 'Altura de oleaje marítimo',
            valorAnterior: '0.8 metros (Calmado)',
            valorActual: '2.2 metros (Mar picado)',
            alertaIdAsociada: 'alt_ballestas_002',
            resumenImpacto: 'Aviso oceanográfico de marejadas del suroeste.',
          ),
          RegistroCambioHistorial(
            id: 'hist_pa_02',
            fechaHora: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
            parametroModificado: 'Índice de radiación UV',
            valorAnterior: '2 (Bajo - Niebla)',
            valorActual: '11+ (Extremo)',
            alertaIdAsociada: 'alt_reserva_003',
            resumenImpacto: 'Disipación total de nubosidad costera en la Reserva.',
          ),
          RegistroCambioHistorial(
            id: 'hist_pa_03',
            fechaHora: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
            parametroModificado: 'Viento en bahía',
            valorAnterior: '12 km/h',
            valorActual: '28 km/h',
            resumenImpacto: 'Inicio de brisa marina vespertina típica.',
          ),
        ],
        alertasActivasIds: ['alt_ballestas_002', 'alt_reserva_003'],
        esMock: true,
      ),

      // 3. ICA (Campiña y Centro)
      DestinoSeguimiento(
        id: 'ica',
        nombre: 'Ica (Campiña y Bodegas)',
        region: 'Ica, Valle Vitivinícola',
        imagen: 'assets/images/carrusel_2_vinos.jpg',
        ultimaActualizacion: DateTime.now().subtract(const Duration(minutes: 50)),
        estadoGeneral: 'Condiciones excelentes para turismo vitivinícola y cultural',
        temperaturaActual: '25°C',
        vientoActual: '11 km/h',
        humedadActual: '45%',
        uvActual: 'Moderado (5)',
        horarioAtencion: HorarioAtencion.paraVinedos(),
        actividadesAptitud: const [
          AptitudActividad(
            actividadTitulo: 'Viñedos y bodegas (Tours y Catas)',
            estado: EstadoAptitud.optima,
            detalleClimatico: 'Temperatura agradable de 25°C con brisa fresca en parronales.',
          ),
          AptitudActividad(
            actividadTitulo: 'Centro histórico y museos de Ica',
            estado: EstadoAptitud.optima,
            detalleClimatico: 'Condiciones urbanas templadas sin precipitaciones.',
          ),
          AptitudActividad(
            actividadTitulo: 'Cata de piscos artesanales',
            estado: EstadoAptitud.optima,
            detalleClimatico: 'Bodegas coloniales frescas con sombra garantizada.',
          ),
        ],
        historialCambios: [
          RegistroCambioHistorial(
            id: 'hist_ica_01',
            fechaHora: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
            parametroModificado: 'Temperatura y cielo',
            valorAnterior: '20°C (Brumoso)',
            valorActual: '24°C (Soleado templado)',
            alertaIdAsociada: 'alt_vinos_historial_004',
            resumenImpacto: 'Estabilización de temperatura óptima para recorridos.',
          ),
          RegistroCambioHistorial(
            id: 'hist_ica_02',
            fechaHora: DateTime.now().subtract(const Duration(days: 3)),
            parametroModificado: 'Humedad relativa',
            valorAnterior: '60%',
            valorActual: '45%',
            resumenImpacto: 'Ambiente seco y soleado ideal en el valle.',
          ),
        ],
        alertasActivasIds: [],
        esMock: true,
      ),
      // 4. SANTUARIO DEL SEÑOR DE LUREN
      DestinoSeguimiento(
        id: 'luren',
        nombre: 'Santuario del Señor de Luren',
        region: 'Ica, Centro Histórico',
        imagen: 'assets/images/act_buggy1.jpg',
        ultimaActualizacion: DateTime.now().subtract(const Duration(minutes: 10)),
        estadoGeneral: 'Condiciones excelentes para turismo religioso y cultural',
        temperaturaActual: '24°C',
        vientoActual: '12 km/h',
        humedadActual: '42%',
        uvActual: 'Moderado (5)',
        horarioAtencion: HorarioAtencion.paraLuren(),
        actividadesAptitud: const [
          AptitudActividad(
            actividadTitulo: 'Visita devocional al Señor de Luren',
            estado: EstadoAptitud.optima,
            detalleClimatico: 'Ambiente interior protegido y templado.',
          ),
          AptitudActividad(
            actividadTitulo: 'Paseo por el Paseo de Luren y alrededores',
            estado: EstadoAptitud.optima,
            detalleClimatico: 'Cielo despejado con brisa suave.',
          ),
        ],
        historialCambios: [
          RegistroCambioHistorial(
            id: 'hist_lu_01',
            fechaHora: DateTime.now().subtract(const Duration(hours: 2)),
            parametroModificado: 'Temperatura urbana',
            valorAnterior: '21°C',
            valorActual: '24°C',
            alertaIdAsociada: '',
            resumenImpacto: 'Clima agradable para visitas patrimoniales.',
          ),
        ],
        alertasActivasIds: [],
        esMock: true,
      ),
    ];

    destinosNotifier.value = mock;
  }

  DestinoSeguimiento? obtenerPorId(String id) {
    try {
      return destinosNotifier.value.firstWhere(
        (d) => d.id.toLowerCase() == id.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  DestinoSeguimiento? obtenerPorNombre(String nombre) {
    try {
      final buscado = nombre.trim().toLowerCase();
      // Búsqueda inteligente por palabras clave (luren, huacachina, paracas, etc.)
      for (final d in destinosNotifier.value) {
        final nomD = d.nombre.toLowerCase();
        if (nomD == buscado || nomD.contains(buscado) || buscado.contains(nomD)) {
          return d;
        }
        // Coincidencia por palabra clave distintiva (ej. 'luren')
        if (buscado.contains('luren') && nomD.contains('luren')) return d;
        if (buscado.contains('huacachina') && nomD.contains('huacachina')) return d;
        if (buscado.contains('paracas') && nomD.contains('paracas')) return d;
      }

      // Si no existe, crear dinámicamente el seguimiento para el destino solicitado
      final idDinamico = nombre.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final nuevo = DestinoSeguimiento(
        id: idDinamico,
        nombre: nombre,
        region: 'Ica, Perú',
        imagen: 'assets/images/carrusel_1_huacachina.jpg',
        ultimaActualizacion: DateTime.now(),
        estadoGeneral: 'Condiciones climáticas favorables en la zona',
        temperaturaActual: '24°C',
        vientoActual: '14 km/h',
        humedadActual: '45%',
        uvActual: 'Moderado (5)',
        horarioAtencion: HorarioAtencion.noConfirmado(),
        actividadesAptitud: [
          AptitudActividad(
            actividadTitulo: 'Recorrido turístico en $nombre',
            estado: EstadoAptitud.optima,
            detalleClimatico: 'Temperatura templada y buena visibilidad.',
          ),
        ],
        historialCambios: const [],
        alertasActivasIds: const [],
        esMock: true,
      );

      destinosNotifier.value = [...destinosNotifier.value, nuevo];
      return nuevo;
    } catch (_) {
      return destinosNotifier.value.isNotEmpty ? destinosNotifier.value.first : null;
    }
  }
}
