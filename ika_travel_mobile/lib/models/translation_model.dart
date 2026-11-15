class PhraseItemModel {
  final String id;
  final String category;
  final String spanish;
  final String english;
  final String? phonetic;

  const PhraseItemModel({
    required this.id,
    required this.category,
    required this.spanish,
    required this.english,
    this.phonetic,
  });

  factory PhraseItemModel.fromJson(Map<String, dynamic> json) {
    return PhraseItemModel(
      id: json['id']?.toString() ?? '',
      category: json['category'] as String? ?? 'general',
      spanish: json['es'] as String? ?? '',
      english: json['en'] as String? ?? '',
      phonetic: json['phonetic'] as String?,
    );
  }
}

class PhrasebookResponseModel {
  final int total;
  final String version;
  final List<PhraseItemModel> phrases;

  const PhrasebookResponseModel({
    required this.total,
    required this.version,
    required this.phrases,
  });

  factory PhrasebookResponseModel.fromJson(Map<String, dynamic> json) {
    final list = (json['phrases'] as List<dynamic>? ?? [])
        .map((e) => PhraseItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return PhrasebookResponseModel(
      total: json['total'] as int? ?? list.length,
      version: json['version'] as String? ?? '',
      phrases: list,
    );
  }
}

/// De dónde salió una traducción. La pantalla lo usa para avisar al usuario
/// cuando el resultado no viene de un traductor real.
enum OrigenTraduccion {
  /// Servicio de traducción del backend.
  servidor,

  /// Gemini, cuando hay internet pero el backend no responde.
  asistenteIA,

  /// Diccionario de viaje embebido en la app, sin internet.
  sinConexion,
}

class TranslationResultModel {
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final OrigenTraduccion origin;

  /// true cuando la traducción puede estar incompleta (quedaron palabras sin
  /// traducir). Solo ocurre en el modo sin conexión.
  final bool aproximada;

  const TranslationResultModel({
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.origin,
    this.aproximada = false,
  });

  factory TranslationResultModel.fromJson(Map<String, dynamic> json) {
    return TranslationResultModel(
      translatedText: json['translated_text'] as String? ?? '',
      sourceLang: json['source_lang'] as String? ?? 'es',
      targetLang: json['target_lang'] as String? ?? 'en',
      origin: OrigenTraduccion.servidor,
    );
  }
}
