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
      total: 3,
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
          spanish: '¿Cuánto cuesta el pasaje en taxi a Huacachina?',
          english: 'How much is the taxi fare to Huacachina?',
        ),
        PhraseItemModel(
          id: '3',
          category: 'services',
          spanish: '¿Tienen menú en inglés?',
          english: 'Do you have an English menu?',
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
      final res = await _apiClient.post('/translation/translate', payload);
      if (res is Map<String, dynamic>) {
        return TranslationResultModel.fromJson(res);
      }
    } catch (e) {
      debugPrint('[TranslationService] Error al traducir texto libre: $e');
      rethrow;
    }

    throw Exception('Respuesta inesperada al traducir');
  }
}
