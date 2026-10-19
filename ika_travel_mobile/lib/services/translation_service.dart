import 'package:flutter/foundation.dart';

import '../models/translation_model.dart';
import 'api_client.dart';

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
          category: 'emergency',
          spanish: '¿Dónde está el hospital más cercano?',
          english: 'Where is the nearest hospital?',
        ),
        PhraseItemModel(
          id: '2',
          category: 'transport',
          spanish: '¿Cuánto cuesta el taxi a la Huacachina?',
          english: 'How much is the taxi fare to Huacachina?',
        ),
        PhraseItemModel(
          id: '3',
          category: 'food',
          spanish: '¿Tiene opciones sin gluten o vegetarianas?',
          english: 'Do you have gluten-free or vegetarian options?',
        ),
        PhraseItemModel(
          id: '4',
          category: 'directions',
          spanish: '¿Cómo llego a la Plaza de Armas?',
          english: 'How do I get to the Main Square?',
        ),
        PhraseItemModel(
          id: '5',
          category: 'courtesy',
          spanish: 'Muchas gracias por su hospitalidad.',
          english: 'Thank you very much for your hospitality.',
        ),
      ],
    );
  }

  /// Traduce texto libre entre español e inglés
  Future<TranslationResultModel> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final payload = {
      'text': text,
      'source_lang': sourceLang,
      'target_lang': targetLang,
    };

    try {
      final res = await _apiClient.post('/translation/translate', body: payload);
      if (res is Map<String, dynamic>) {
        return TranslationResultModel.fromJson(res);
      }
    } catch (e) {
      debugPrint('[TranslationService] Error al traducir texto libre: $e');
      // Si la API no está disponible en modo offline, podemos devolver una traducción aproximada o rethrow
      return TranslationResultModel(
        translatedText: 'Traducción simulada offline: $text ($targetLang)',
        sourceLang: sourceLang,
        targetLang: targetLang,
        origin: 'offline-fallback',
      );
    }

    throw Exception('Respuesta inesperada al traducir');
  }
}
