import 'package:flutter/material.dart';
import '../models/navegacion_modelo.dart';

/// Genera textos descriptivos en español natural e íconos direccionales
/// a partir de las maniobras sinópticas de OSRM.
class TraductorManiobras {
  TraductorManiobras._();

  /// Genera una instrucción clara en español para el paso de navegación
  static String traducir({
    required ManiobraPaso maniobra,
    required String nombreVia,
    String? nombreDestino,
  }) {
    final via = nombreVia.trim().isNotEmpty ? nombreVia.trim() : 'la vía';

    switch (maniobra.tipo) {
      case TipoManiobra.depart:
        return 'Inicie el recorrido por $via';

      case TipoManiobra.arrive:
        if (nombreDestino != null && nombreDestino.trim().isNotEmpty) {
          return 'Ha llegado a su destino: ${nombreDestino.trim()}';
        }
        return 'Ha llegado a su destino';

      case TipoManiobra.turn:
        return switch (maniobra.modificador) {
          ModificadorManiobra.uturn => 'Haga un giro en U en $via',
          ModificadorManiobra.sharpRight =>
            'Gire pronunciadamente a la derecha en $via',
          ModificadorManiobra.right => 'Gire a la derecha en $via',
          ModificadorManiobra.slightRight =>
            'Gire ligeramente a la derecha hacia $via',
          ModificadorManiobra.straight => 'Continúe recto por $via',
          ModificadorManiobra.slightLeft =>
            'Gire ligeramente a la izquierda hacia $via',
          ModificadorManiobra.left => 'Gire a la izquierda en $via',
          ModificadorManiobra.sharpLeft =>
            'Gire pronunciadamente a la izquierda en $via',
          ModificadorManiobra.ninguno => 'Gire hacia $via',
        };

      case TipoManiobra.newName:
        return 'Continúe por $via';

      case TipoManiobra.continueStraight:
        return 'Continúe recto por $via';

      case TipoManiobra.roundabout:
      case TipoManiobra.rotary:
      case TipoManiobra.roundaboutTurn:
        return 'En el óvalo/rotonda, tome la salida hacia $via';

      case TipoManiobra.merge:
        return 'Incorpórese a $via';

      case TipoManiobra.fork:
        if (maniobra.modificador == ModificadorManiobra.right ||
            maniobra.modificador == ModificadorManiobra.slightRight) {
          return 'En la bifurcación, manténgase a la derecha hacia $via';
        } else if (maniobra.modificador == ModificadorManiobra.left ||
            maniobra.modificador == ModificadorManiobra.slightLeft) {
          return 'En la bifurcación, manténgase a la izquierda hacia $via';
        }
        return 'Tome la bifurcación hacia $via';

      case TipoManiobra.onRamp:
        return 'Tome la rampa hacia $via';

      case TipoManiobra.offRamp:
        return 'Tome la salida hacia $via';

      case TipoManiobra.endOfRoad:
        if (maniobra.modificador == ModificadorManiobra.right ||
            maniobra.modificador == ModificadorManiobra.sharpRight) {
          return 'Al final de la calle, doble a la derecha en $via';
        } else if (maniobra.modificador == ModificadorManiobra.left ||
            maniobra.modificador == ModificadorManiobra.sharpLeft) {
          return 'Al final de la calle, doble a la izquierda en $via';
        }
        return 'Al final de la calle, gire hacia $via';

      case TipoManiobra.desconocido:
        return 'Continúe el trayecto hacia $via';
    }
  }

  /// Retorna el ícono direccional correspondiente a la maniobra
  static IconData obtenerIcono(ManiobraPaso maniobra) {
    switch (maniobra.tipo) {
      case TipoManiobra.depart:
        return Icons.navigation_rounded;

      case TipoManiobra.arrive:
        return Icons.flag_rounded;

      case TipoManiobra.turn:
      case TipoManiobra.endOfRoad:
        return switch (maniobra.modificador) {
          ModificadorManiobra.uturn => Icons.u_turn_left_rounded,
          ModificadorManiobra.sharpRight ||
          ModificadorManiobra.right ||
          ModificadorManiobra.slightRight =>
            Icons.turn_right_rounded,
          ModificadorManiobra.sharpLeft ||
          ModificadorManiobra.left ||
          ModificadorManiobra.slightLeft =>
            Icons.turn_left_rounded,
          _ => Icons.straight_rounded,
        };

      case TipoManiobra.roundabout:
      case TipoManiobra.rotary:
      case TipoManiobra.roundaboutTurn:
        return Icons.roundabout_right_rounded;

      case TipoManiobra.merge:
      case TipoManiobra.fork:
        if (maniobra.modificador == ModificadorManiobra.right ||
            maniobra.modificador == ModificadorManiobra.slightRight) {
          return Icons.call_split_rounded;
        }
        return Icons.alt_route_rounded;

      case TipoManiobra.onRamp:
      case TipoManiobra.offRamp:
        return Icons.ramp_right_rounded;

      case TipoManiobra.newName:
      case TipoManiobra.continueStraight:
      case TipoManiobra.desconocido:
        return Icons.straight_rounded;
    }
  }
}
