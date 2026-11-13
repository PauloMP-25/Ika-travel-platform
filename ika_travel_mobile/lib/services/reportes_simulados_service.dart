import 'package:flutter/foundation.dart';

class ReporteModel {
  final String id;
  final String descripcion;
  final String latitud;
  final String longitud;
  final String fecha;
  final String estado; // "Pendiente", "Atendido"

  ReporteModel({
    required this.id,
    required this.descripcion,
    required this.latitud,
    required this.longitud,
    required this.fecha,
    this.estado = "Pendiente",
  });
}

// Lista global para que los turistas (RF-17) y el admin (RF-21) compartan datos
final ValueNotifier<List<ReporteModel>> reportesGlobales =
    ValueNotifier<List<ReporteModel>>([
      ReporteModel(
        id: "1",
        descripcion: "Venta de tours sin boleta en la entrada de Huacachina.",
        latitud: "-14.0875",
        longitud: "-75.7288",
        fecha: "2026-05-12",
      ),
      ReporteModel(
        id: "2",
        descripcion:
            "Guía informal ofreciendo paseos en buggy sin chaleco salvavidas.",
        latitud: "-14.0685",
        longitud: "-75.7288",
        fecha: "2026-05-11",
      ),
    ]);
