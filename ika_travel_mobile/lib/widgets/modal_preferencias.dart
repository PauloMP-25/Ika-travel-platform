import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../services/preferencias_service.dart';

/// Modal (hoja inferior) que aparece la primera vez que el usuario entra a la
/// app tras iniciar sesión. Recoge sus gustos de viaje para que la IA de
/// recomendaciones personalice los consejos.
class ModalPreferencias {
  static Future<void> mostrar(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ContenidoPreferencias(),
    );
  }
}

class _Opcion {
  final String etiqueta;
  final IconData icono;
  const _Opcion(this.etiqueta, this.icono);
}

class _ContenidoPreferencias extends StatefulWidget {
  const _ContenidoPreferencias();

  @override
  State<_ContenidoPreferencias> createState() => _ContenidoPreferenciasState();
}

class _ContenidoPreferenciasState extends State<_ContenidoPreferencias> {
  static const List<_Opcion> _intereses = [
    _Opcion('Aventura y adrenalina', Icons.surfing_rounded),
    _Opcion('Gastronomía y pisco', Icons.wine_bar_rounded),
    _Opcion('Cultura e historia', Icons.account_balance_rounded),
    _Opcion('Naturaleza y mar', Icons.waves_rounded),
    _Opcion('Relax y bienestar', Icons.spa_rounded),
    _Opcion('Fotografía', Icons.photo_camera_rounded),
    _Opcion('Playas', Icons.beach_access_rounded),
    _Opcion('Vida nocturna', Icons.nightlife_rounded),
  ];

  static const List<_Opcion> _estilos = [
    _Opcion('Tranquilo', Icons.self_improvement_rounded),
    _Opcion('Equilibrado', Icons.balance_rounded),
    _Opcion('Aventurero', Icons.hiking_rounded),
  ];

  static const List<_Opcion> _presupuestos = [
    _Opcion('Económico', Icons.savings_rounded),
    _Opcion('Medio', Icons.payments_rounded),
    _Opcion('Premium', Icons.diamond_rounded),
  ];

  static const List<_Opcion> _companias = [
    _Opcion('Solo', Icons.person_rounded),
    _Opcion('Pareja', Icons.favorite_rounded),
    _Opcion('Familia', Icons.family_restroom_rounded),
    _Opcion('Amigos', Icons.groups_rounded),
  ];

  final Set<String> _interesesSel = {};
  String _estilo = '';
  String _presupuesto = '';
  String _compania = '';
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    await PreferenciasService().guardar(
      intereses: _interesesSel.toList(),
      estilo: _estilo,
      presupuesto: _presupuesto,
      compania: _compania,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _omitir() async {
    await PreferenciasService().omitir();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 1 a 3 gustos para poder continuar.
    final puedeGuardar = _interesesSel.isNotEmpty &&
        _interesesSel.length <= 3 &&
        !_guardando;
    // Bloquea el cierre por gesto/botón "atrás": solo Omitir o Continuar.
    return PopScope(
      canPop: false,
      child: _hoja(puedeGuardar),
    );
  }

  Widget _hoja(bool puedeGuardar) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColores.arenaFondo,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  children: [
                    _encabezado(),
                    const SizedBox(height: 22),
                    _bloque(
                      '¿Qué te gusta? (elige de 1 a 3)',
                      Icons.favorite_border_rounded,
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _intereses
                            .map((o) => _chipMulti(o))
                            .toList(),
                      ),
                    ),
                    _bloque(
                      'Tu ritmo de viaje',
                      Icons.speed_rounded,
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _estilos
                            .map((o) => _chipUnico(
                                o, _estilo, (v) => setState(() => _estilo = v)))
                            .toList(),
                      ),
                    ),
                    _bloque(
                      'Presupuesto',
                      Icons.account_balance_wallet_rounded,
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presupuestos
                            .map((o) => _chipUnico(o, _presupuesto,
                                (v) => setState(() => _presupuesto = v)))
                            .toList(),
                      ),
                    ),
                    _bloque(
                      '¿Con quién viajas?',
                      Icons.group_rounded,
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _companias
                            .map((o) => _chipUnico(o, _compania,
                                (v) => setState(() => _compania = v)))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              _barraInferior(puedeGuardar),
            ],
          ),
        );
      },
    );
  }

  Widget _encabezado() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColores.naranjaBoton, AppColores.turquesaOasis],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuéntanos tus gustos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Personalizamos tus recomendaciones de Ica con inteligencia '
                  'artificial según lo que más disfrutas.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloque(String titulo, IconData icono, Widget contenido) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: AppColores.naranjaBoton),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColores.marronOscuro,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          contenido,
        ],
      ),
    );
  }

  Widget _chipMulti(_Opcion o) {
    final sel = _interesesSel.contains(o.etiqueta);
    return _chipBase(o, sel, () {
      if (sel) {
        setState(() => _interesesSel.remove(o.etiqueta));
      } else if (_interesesSel.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Puedes elegir hasta 3 gustos.'),
            backgroundColor: AppColores.marronOscuro,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        setState(() => _interesesSel.add(o.etiqueta));
      }
    });
  }

  Widget _chipUnico(_Opcion o, String valorActual, ValueChanged<String> onSel) {
    final sel = valorActual == o.etiqueta;
    return _chipBase(o, sel, () => onSel(sel ? '' : o.etiqueta));
  }

  Widget _chipBase(_Opcion o, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColores.naranjaBoton : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel
                ? AppColores.naranjaBoton
                : Colors.black.withValues(alpha: 0.10),
          ),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: AppColores.naranjaBoton.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              o.icono,
              size: 17,
              color: sel ? Colors.white : AppColores.turquesaOasis,
            ),
            const SizedBox(width: 7),
            Text(
              o.etiqueta,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppColores.marronOscuro,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraInferior(bool puedeGuardar) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _guardando ? null : _omitir,
            style: TextButton.styleFrom(
              foregroundColor: AppColores.grisTexto,
            ),
            child: const Text('Omitir por ahora'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: puedeGuardar ? _guardar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaBoton,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColores.naranjaBoton.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: _guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Guardar preferencias',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
