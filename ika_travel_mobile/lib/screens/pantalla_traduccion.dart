import 'package:flutter/material.dart';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../models/translation_model.dart';
import '../services/translation_service.dart';

class PantallaTraduccion extends StatefulWidget {
  final TranslationService? translationService;

  /// Cuando es true se muestra como pestaña de la barra inferior (sin botón atrás).
  final bool comoPestana;

  const PantallaTraduccion({
    super.key,
    this.translationService,
    this.comoPestana = false,
  });

  @override
  State<PantallaTraduccion> createState() => _PantallaTraduccionState();
}

class _PantallaTraduccionState extends State<PantallaTraduccion> {
  int _tabIndex = 0;
  late final TranslationService _translationService;

  PhrasebookResponseModel? _phrasebook;
  bool _cargandoFrases = true;
  String _filtroCategoria = '';

  final TextEditingController _textoController = TextEditingController();
  String _sourceLang = 'es';
  String _targetLang = 'en';
  String _traduccionResultado = '';
  String _origenTraduccion = '';
  bool _traduciendo = false;
  String? _errorTraduccion;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechDisponible = false;
  bool _escuchando = false;

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
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechDisponible = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _escuchando = false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _escuchando = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error de voz: ${error.errorMsg}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechDisponible = false;
    }
  }

  Future<void> _toggleEscucha() async {
    if (!_speechDisponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El reconocimiento de voz no está disponible en este dispositivo.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_escuchando) {
      await _speech.stop();
      if (mounted) setState(() => _escuchando = false);
      return;
    }

    // Limpia el texto previo antes de dictar
    _textoController.clear();

    // El idioma del dictado sigue al idioma de origen del traductor
    final localeId = _sourceLang == 'es' ? 'es_ES' : 'en_US';

    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
    );

    if (mounted) setState(() => _escuchando = true);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final texto = result.recognizedWords;
    if (texto.isEmpty) return;

    setState(() {
      _textoController.text = texto;
      _textoController.selection = TextSelection.fromPosition(
        TextPosition(offset: texto.length),
      );
    });

    if (result.finalResult) {
      setState(() => _escuchando = false);
    }
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
          _errorTraduccion = context.tr('error_traduccion');
          _traduciendo = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    _textoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorFondo = TemaApp.fondo(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (!widget.comoPestana)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colorTexto, size: 28),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('traductor_guia'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: colorTarjeta,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTabButton(
                      context.tr('frases_oficiales'),
                      0,
                      colorTexto,
                      colorTextoSecundario,
                    ),
                    _buildTabButton(
                      context.tr('traductor_libre'),
                      1,
                      colorTexto,
                      colorTextoSecundario,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _tabIndex == 0
                  ? _buildVistaFrasebook(
                      colorTarjeta,
                      colorTexto,
                      colorTextoSecundario,
                    )
                  : _buildVistaTraductorLibre(
                      colorTarjeta,
                      colorTexto,
                      colorTextoSecundario,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    String texto,
    int index,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
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
                color: activo ? Colors.white : colorTextoSecundario,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVistaFrasebook(
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categorias.length,
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              final bool seleccionada = _filtroCategoria == cat['id'];

              String nombreCat = cat['nombre']!;
              if (cat['id'] == '') nombreCat = context.tr('categoria_todas');
              if (cat['id'] == 'emergency')
                nombreCat = context.tr('cat_emergencia');
              if (cat['id'] == 'health') nombreCat = context.tr('cat_salud');
              if (cat['id'] == 'transport')
                nombreCat = context.tr('cat_transporte');
              if (cat['id'] == 'services')
                nombreCat = context.tr('cat_servicios');
              if (cat['id'] == 'directions')
                nombreCat = context.tr('cat_direcciones');
              if (cat['id'] == 'lodging')
                nombreCat = context.tr('cat_hospedaje');
              if (cat['id'] == 'food') nombreCat = context.tr('cat_comida');
              if (cat['id'] == 'courtesy')
                nombreCat = context.tr('cat_cortesia');

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(nombreCat),
                  selected: seleccionada,
                  selectedColor: AppColores.naranjaBoton,
                  backgroundColor: colorTarjeta,
                  labelStyle: TextStyle(
                    color: seleccionada ? Colors.white : colorTexto,
                    fontWeight: seleccionada
                        ? FontWeight.bold
                        : FontWeight.normal,
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
        Expanded(
          child: _cargandoFrases
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColores.naranjaBoton,
                  ),
                )
              : RefreshIndicator(
                  color: AppColores.naranjaBoton,
                  onRefresh: _cargarFrases,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _phrasebook?.phrases.length ?? 0,
                    itemBuilder: (context, index) {
                      final item = _phrasebook!.phrases[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: colorTexto,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.category.toUpperCase(),
                                    style: const TextStyle(
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
                                color: colorTextoSecundario,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (item.phonetic != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '[ ${item.phonetic} ]',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorTextoSecundario,
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

  Widget _buildVistaTraductorLibre(
    Color colorTarjeta,
    Color colorTexto,
    Color colorTextoSecundario,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorTarjeta,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  _sourceLang == 'es' ? 'Español' : 'Inglés',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorTexto,
                  ),
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
                  _targetLang == 'en' ? 'Inglés' : 'Español',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorTexto,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: colorTarjeta,
              borderRadius: BorderRadius.circular(16),
              border: _escuchando
                  ? Border.all(color: AppColores.naranjaBoton, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _textoController,
                  maxLines: 4,
                  maxLength: 500,
                  style: TextStyle(color: colorTexto),
                  decoration: InputDecoration(
                    hintText: context.tr('escribe_frase'),
                    hintStyle: TextStyle(color: colorTextoSecundario),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_escuchando)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Escuchando...',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColores.naranjaBoton,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: _escuchando
                            ? 'Detener dictado'
                            : 'Dictar por voz',
                        onPressed: _toggleEscucha,
                        icon: Icon(
                          _escuchando ? Icons.stop_circle : Icons.mic,
                          color: _escuchando
                              ? Colors.red
                              : AppColores.naranjaBoton,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.naranjaBoton,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                : Text(
                    context.tr('traducir_ia'),
                    style: const TextStyle(
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
                color: colorTarjeta,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColores.naranjaBoton.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                      Text(
                        context.tr('traduccion'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colorTextoSecundario,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${context.tr('fuente')} $_origenTraduccion',
                          style: const TextStyle(
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
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
