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

  void _intercambiarIdiomas() {
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
      _traduccionResultado = '';
      _errorTraduccion = null;
    });
  }

  Future<void> _realizarTraduccion() async {
    final texto = _textoController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _traduciendo = true;
      _errorTraduccion = null;
      _traduccionResultado = '';
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
          _errorTraduccion = 'No se pudo traducir. Intente con frases oficiales.';
          _traduciendo = false;
        });
      }
    }
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
      body: SafeArea(
        child: Column(
          children: [
            // AppBar personalizado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColores.marronOscuro,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Traductor y Guía Bilingüe',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColores.marronOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Selector de pestaña (Frasebook oficial / Traducción libre)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Frases oficiales', 0),
                    _buildTabButton('Traductor libre', 1),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Vista activa
            Expanded(
              child: _tabIndex == 0
                  ? _buildVistaFrasebook()
                  : _buildVistaTraductorLibre(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String texto, int index) {
    final bool activo = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: activo ? AppColores.marronOscuro : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                color: activo ? Colors.white : AppColores.grisTexto,
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
        // Chips horizontales de categorías
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categorias.length,
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              final bool seleccionada = _filtroCategoria == cat['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat['nombre']!),
                  selected: seleccionada,
                  selectedColor: AppColores.naranjaBoton,
                  labelStyle: TextStyle(
                    color: seleccionada ? Colors.white : AppColores.marronOscuro,
                    fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    setState(() {
                      _filtroCategoria = val ? cat['id']! : '';
                    });
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
              ? const Center(
                  child: CircularProgressIndicator(color: AppColores.naranjaBoton),
                )
              : RefreshIndicator(
                  color: AppColores.naranjaBoton,
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
                                Expanded(
                                  child: Text(
                                    item.spanish,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColores.marronOscuro,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
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
                            if (item.phonetic != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '[ ${item.phonetic} ]',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColores.grisTexto,
                                ),
                              ),
                            ],
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  _sourceLang == 'es' ? '🇪🇸 Español' : '🇺🇸 Inglés',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.swap_horiz,
                    color: AppColores.naranjaBoton,
                    size: 28,
                  ),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Traducir con IA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
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
                border: Border.all(
                  color: AppColores.naranjaBoton.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Traducción:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColores.grisTexto,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Fuente: $_origenTraduccion',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColores.naranjaBoton,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _traduccionResultado,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColores.marronOscuro,
                    ),
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
