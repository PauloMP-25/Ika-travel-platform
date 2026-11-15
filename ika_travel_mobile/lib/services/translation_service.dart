import 'package:flutter/foundation.dart';

import '../models/translation_model.dart';
import 'api_client.dart';
import 'gemini_service.dart';
import 'traductor_offline.dart';

class TranslationService {
  final ApiClient _apiClient;

  TranslationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Obtiene el frasebook oficial versionado con ETag
  Future<PhrasebookResponseModel> getPhrases({String? category}) async {
    try {
      final query = category != null && category.isNotEmpty
          ? '?category=${Uri.encodeComponent(category)}'
          : '';
      final data = await _apiClient.get('/translation/phrases$query');
      if (data is Map<String, dynamic>) {
        return PhrasebookResponseModel.fromJson(data);
      }
    } catch (e) {
      debugPrint('[TranslationService] Error al obtener frasebook: $e. Usando respaldo.');
    }

    return const PhrasebookResponseModel(
      total: 5,
      version: 'offline-seed',
      phrases: [
        PhraseItemModel(
          id: '1',
          category: 'emergencia',
          spanish: '¿Dónde está el hospital más cercano?',
          english: 'Where is the nearest hospital?',
        ),
        PhraseItemModel(
          id: '2',
          category: 'transporte',
          spanish: '¿Cuánto cuesta el taxi a la Huacachina?',
          english: 'How much is the taxi fare to Huacachina?',
        ),
        PhraseItemModel(
          id: '3',
          category: 'alimentacion',
          spanish: '¿Tiene opciones sin gluten o vegetarianas?',
          english: 'Do you have gluten-free or vegetarian options?',
        ),
        PhraseItemModel(
          id: '4',
          category: 'orientacion',
          spanish: '¿Cómo llego a la Plaza de Armas?',
          english: 'How do I get to the Main Square?',
        ),
        PhraseItemModel(
          id: '5',
          category: 'saludos',
          spanish: 'Muchas gracias por su hospitalidad.',
          english: 'Thank you very much for your hospitality.',
        ),
      ],
    );
  }

  /// Traduce texto libre entre español e inglés.
  ///
  /// Prueba tres vías en orden, de mejor a peor, y nunca lanza excepción si
  /// el texto se puede traducir de alguna forma:
  ///
  /// 1. **Servidor**: el endpoint `/translation/translate` del backend.
  /// 2. **Asistente IA**: Gemini directo, para cuando el backend está caído
  ///    pero el teléfono sí tiene internet.
  /// 3. **Sin conexión**: diccionario de viaje embebido en la app.
  Future<TranslationResultModel> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    // 1. Backend.
    try {
      final res = await _apiClient.post(
        '/translation/translate',
        body: {
          'text': text,
          'source_lang': sourceLang,
          'target_lang': targetLang,
        },
      );
      if (res is Map<String, dynamic>) {
        final modelo = TranslationResultModel.fromJson(res);
        if (modelo.translatedText.trim().isNotEmpty) return modelo;
      }
      debugPrint('[TranslationService] El servidor respondió sin traducción.');
    } catch (e) {
      debugPrint('[TranslationService] Servidor no disponible: $e');
    }

    // 2. Gemini directo.
    final porIA = await GeminiService().traducir(
      texto: text,
      idiomaOrigen: sourceLang,
      idiomaDestino: targetLang,
    );
    if (porIA != null && porIA.trim().isNotEmpty) {
      debugPrint('[TranslationService] Traducción resuelta con el asistente IA.');
      return TranslationResultModel(
        translatedText: porIA,
        sourceLang: sourceLang,
        targetLang: targetLang,
        origin: OrigenTraduccion.asistenteIA,
      );
    }

    // 3. Diccionario local.
    if (TraductorOffline.soporta(sourceLang, targetLang)) {
      final local = TraductorOffline.traducir(
        texto: text,
        origen: sourceLang,
        destino: targetLang,
      );
      debugPrint('[TranslationService] Traducción sin conexión '
          '(cobertura ${(local.cobertura * 100).toStringAsFixed(0)}%).');
      return TranslationResultModel(
        translatedText: local.texto,
        sourceLang: sourceLang,
        targetLang: targetLang,
        origin: OrigenTraduccion.sinConexion,
        aproximada: local.aproximada,
      );
    }

    // Par de idiomas que el diccionario local no cubre: que la pantalla
    // muestre su mensaje de error en vez de inventar una traducción.
    throw Exception('No se pudo traducir de $sourceLang a $targetLang');
  }
}
