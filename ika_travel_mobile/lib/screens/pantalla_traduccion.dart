import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../models/translation_model.dart';
import '../services/translation_service.dart';

class PantallaTraduccion extends StatefulWidget {
  final TranslationService? translationService;

  const PantallaTraduccion({super.key, this.translationService});

  @override
  State<PantallaTraduccion> createState() => _PantallaTraduccionState();
}

class _PantallaTraduccionState extends State<PantallaTraduccion> {
  int _tabIndex = 0; // 0 = Frases oficiales, 1 = Traductor libre
  late final TranslationService _translationService;

  // Frasebook
  PhrasebookResponseModel? _phrasebook;
  bool _cargandoFrases = true;
  String _filtroCategoria = '';

  // Traducción libre
  final TextEditingController _textoController = TextEditingController();
  String _sourceLang = 'es';
  String _targetLang = 'en';
  String _traduccionResultado = '';
  String _origenTraduccion = '';
  bool _traduciendo = false;
  String? _errorTraduccion;

  final List<Map<String, String>> _categorias = [
    {'id': '', 'nombre': 'Todas'},
    {'id': 'emergency', 'nombre': 'Emergencia'},
    {'id': 'health', 'nombre': 'Salud'},
    {'id': 'transport', 'nombre': 'Transporte'},
    {'id': 'services', 'nombre': 'Servicios'},
    {'id': 'directions', 'nombre': 'Direcciones'},
    {'id': 'lodging', 'nombre': 'Hospedaje'},
    {'id': 'food', 'nombre': 'Comida'},
    {'id': 'courtesy', 'nombre': 'Cortesía'},
  ];

  @override
  void initState() {
    super.initState();
    _translationService = widget.translationService ?? TranslationService();
    _cargarFrases();
  }

  Future<void> _cargarFrases() async {
    setState(() => _cargandoFrases = true);
    final data = await _translationService.getPhrases(
      category: _filtroCategoria.isNotEmpty ? _filtroCategoria : null,
    );
    if (mounted) {
      setState(() {
        _phrasebook = data;
        _cargandoFrases = false;
      });
    }
  }

  Future<void> _realizarTraduccion() async {
    final texto = _textoController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _traduciendo = true;
      _errorTraduccion = null;
    });

    try {
      final res = await _translationService.translate(
        text: texto,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
      );
      if (mounted) {
        setState(() {
          _traduccionResultado = res.translatedText;
          _origenTraduccion = res.origin;
          _traduciendo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorTraduccion = 'No se pudo completar la traducción. Verifica la conexión.';
          _traduciendo = false;
        });
      }
    }
  }

  void _intercambiarIdiomas() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      _traduccionResultado = '';
    });
  }

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.arenaFondo,
      appBar: AppBar(
        title: const Text('Guía de Frases & Traductor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selector de pestaña
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _botonTab('Frases Oficiales', 0),
                    _botonTab('Traductor Libre', 1),
                  ],
                ),
              ),
            ),

            Expanded(
              child: _tabIndex == 0 ? _buildVistaFrasebook() : _buildVistaTraductorLibre(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonTab(String titulo, int index) {
    final activo = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: activo ? AppColores.naranjaBoton : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              titulo,
              style: TextStyle(
                color: activo ? Colors.white : AppColores.marronOscuro,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVistaFrasebook() {
    return Column(
      children: [
        // Categorías Horizontales
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categorias.length,
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              final activa = _filtroCategoria == cat['id'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(cat['nombre']!),
                  selected: activa,
                  selectedColor: AppColores.marronOscuro,
                  labelStyle: TextStyle(
                    color: activa ? Colors.white : AppColores.marronOscuro,
                    fontSize: 13,
                  ),
                  backgroundColor: Colors.white,
                  onSelected: (val) {
                    setState(() => _filtroCategoria = cat['id']!);
                    _cargarFrases();
                  },
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Lista de frases
        Expanded(
          child: _cargandoFrases
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargarFrases,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _phrasebook?.phrases.length ?? 0,
                    itemBuilder: (context, index) {
                      final item = _phrasebook!.phrases[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.spanish,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColores.marronOscuro,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.category.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColores.naranjaBoton,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.english,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blueGrey.shade800,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildVistaTraductorLibre() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de Idiomas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  _sourceLang == 'es' ? '🇪🇸 Español' : '🇺🇸 Inglés',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, color: AppColores.naranjaBoton, size: 28),
                  onPressed: _intercambiarIdiomas,
                ),
                Text(
                  _targetLang == 'en' ? '🇺🇸 Inglés' : '🇪🇸 Español',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Caja de texto de entrada
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _textoController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Escribe aquí la consulta o frase...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Botón Traducir
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.naranjaBoton,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _traduciendo ? null : _realizarTraduccion,
            child: _traduciendo
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Traducir con IA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
          ),

          if (_errorTraduccion != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorTraduccion!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],

          if (_traduccionResultado.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColores.naranjaBoton.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Resultado:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColores.grisTexto),
                      ),
                      Text(
                        'Origen: $_origenTraduccion',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _traduccionResultado,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColores.marronOscuro),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
