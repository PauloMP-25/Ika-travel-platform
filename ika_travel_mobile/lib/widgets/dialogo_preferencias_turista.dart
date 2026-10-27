import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../models/usuario_modelo.dart';
import '../services/auth_service.dart';

/// Diálogo interactivo para que el turista gestione sus preferencias de viaje en Ika (RF-01).
class DialogoPreferenciasTurista extends StatefulWidget {
  final UsuarioModelo usuario;

  const DialogoPreferenciasTurista({
    super.key,
    required this.usuario,
  });

  static Future<void> mostrar(BuildContext context, UsuarioModelo usuario) {
    return showDialog(
      context: context,
      builder: (ctx) => DialogoPreferenciasTurista(usuario: usuario),
    );
  }

  @override
  State<DialogoPreferenciasTurista> createState() => _DialogoPreferenciasTuristaState();
}

class _DialogoPreferenciasTuristaState extends State<DialogoPreferenciasTurista> {
  late List<String> _preferenciasSeleccionadas;
  bool _guardando = false;

  final Map<String, String> _catalogoPreferencias = {
    'aventura': 'Aventura en Dunas y Sandboard',
    'naturaleza': 'Fauna Marina e Islas Ballestas',
    'vino_pisco': 'Enoturismo y Ruta del Pisco',
    'cultura': 'Cultura, Arqueología y Templos',
    'sol_playa': 'Playas y Descanso en Paracas',
  };

  @override
  void initState() {
    super.initState();
    _preferenciasSeleccionadas = List<String>.from(widget.usuario.preferences);
  }

  void _toggle(String clave) {
    setState(() {
      if (_preferenciasSeleccionadas.contains(clave)) {
        _preferenciasSeleccionadas.remove(clave);
      } else {
        _preferenciasSeleccionadas.add(clave);
      }
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    await AuthService().actualizarPreferencias(_preferenciasSeleccionadas);
    if (mounted) {
      setState(() => _guardando = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Preferencias turísticas actualizadas con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorFondo = TemaApp.tarjeta(context);

    return AlertDialog(
      backgroundColor: colorFondo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColores.naranjaBoton.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.travel_explore, color: AppColores.naranjaBoton),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Preferencias del Turista',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorTexto,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona los tipos de actividades que más te interesan para personalizar tus recomendaciones en Ica:',
              style: TextStyle(fontSize: 12, color: AppColores.grisTexto, height: 1.3),
            ),
            const SizedBox(height: 14),
            ..._catalogoPreferencias.entries.map((entry) {
              final seleccionada = _preferenciasSeleccionadas.contains(entry.key);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: seleccionada
                      ? AppColores.naranjaBoton.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: seleccionada ? AppColores.naranjaBoton : Colors.grey.shade300,
                  ),
                ),
                child: CheckboxListTile(
                  dense: true,
                  activeColor: AppColores.naranjaBoton,
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                      color: colorTexto,
                    ),
                  ),
                  value: seleccionada,
                  onChanged: (_) => _toggle(entry.key),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: AppColores.grisTexto)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColores.naranjaBoton,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
