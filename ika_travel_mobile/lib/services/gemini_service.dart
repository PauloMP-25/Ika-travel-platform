import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Servicio para integración directa con Google Gemini AI y respaldo offline.
/// Permite que los desarrolladores y compañeros de equipo prueben el frontend
/// con recomendaciones generadas por IA aún si no tienen el backend levantado.
class GeminiService {
  static final GeminiService _instancia = GeminiService._interno();
  factory GeminiService() => _instancia;
  GeminiService._interno();

  /// Genera la recomendación del día impulsada por Gemini.
  /// 1. Si existe clave [ApiConfig.geminiApiKey], consulta la API oficial de Google Gemini (gemini-1.5-flash).
  /// 2. Si falla o no se configuró clave, devuelve una recomendación estructurada de alta fidelidad basada en el clima de Ica.
  Future<Map<String, dynamic>> generarRecomendacionDelDia({
    Map<String, dynamic>? clima,
    String nombreAtractivo = 'Oasis de Huacachina',
  }) async {
    final temp = clima?['temperatura_actual'] ?? 26.0;
    final viento = clima?['velocidad_viento'] ?? 14.0;
    final uv = clima?['indice_uv'] ?? 9.0;
    final condicion = clima?['descripcion_clima'] ?? 'Cielo despejado con sol radiante';

    if (ApiConfig.geminiApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${ApiConfig.geminiApiKey}',
        );

        final prompt = '''
Eres un guía turístico experto en la región Ica (Perú) y seguridad meteorológica.
Genera una recomendación para visitar "$nombreAtractivo" bajo las siguientes condiciones climáticas:
- Temperatura: ${temp}°C
- Viento: ${viento} km/h
- Radiación UV: ${uv}
- Condición: $condicion

Responde EXCLUSIVAMENTE en formato JSON con la siguiente estructura:
{
  "recommendation_text": "Breve párrafo explicativo de 2 a 3 oraciones.",
  "consejos": ["Consejo 1 sobre protección", "Consejo 2 sobre vestimenta o actividades", "Consejo 3 sobre horario"],
  "score": 0.95,
  "nivel": "excelente"
}
''';

        final body = json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.4,
            'maxOutputTokens': 400,
          }
        });

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final rawText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
          final jsonStr = rawText.replaceAll(RegExp(r'```json|```'), '').trim();
          final parsed = json.decode(jsonStr);

          return {
            'atractivo_id': '11111111-1111-1111-1111-111111111111',
            'atractivo_nombre': nombreAtractivo,
            'score': (parsed['score'] as num?)?.toDouble() ?? 0.90,
            'nivel': parsed['nivel'] ?? 'excelente',
            'recommendation_text': parsed['recommendation_text'] ?? '',
            'consejos': List<String>.from(parsed['consejos'] ?? []),
            'source': 'gemini_direct_api',
            'generated_at': DateTime.now().toIso8601String(),
          };
        }
      } catch (e) {
        debugPrint('⚠️ Error al consultar Gemini API directa: $e. Usando motor estructurado offline.');
      }
    }

    // Fallback inteligente offline
    return obtenerRecomendacionOffline(
      nombreAtractivo: nombreAtractivo,
      temperatura: (temp as num).toDouble(),
      viento: (viento as num).toDouble(),
      uv: (uv as num).toDouble(),
      condicion: condicion.toString(),
    );
  }

  /// Recomendación heurística enriquecida de IA cuando no hay conexión
  Map<String, dynamic> obtenerRecomendacionOffline({
    required String nombreAtractivo,
    required double temperatura,
    required double viento,
    required double uv,
    required String condicion,
  }) {
    double score = 0.92;
    String nivel = 'excelente';
    List<String> consejos = [
      'Aplicar bloqueador solar FPS 50+ cada 2 horas por índice UV $uv.',
      'Llevar lentes de sol y gorro con visera para protegerse de la radiación.',
      'Mantener hidratación constante con agua fresca.',
    ];

    if (viento >= 25) {
      score -= 0.15;
      nivel = 'bueno';
      consejos.add('Llevar cortavientos o gafas protectoras ante ráfagas de arena (viento a ${viento.toStringAsFixed(0)} km/h).');
    }

    if (temperatura >= 28) {
      consejos.add('Usar calzado cerrado deportivo si sube a las dunas para evitar quemaduras por arena caliente.');
    }

    final texto = 'Condiciones óptimas en $nombreAtractivo con ${temperatura.toStringAsFixed(0)}°C y $condicion. El clima es propicio para paseos en tubulares, sandboarding y fotografía en las dunas con excelente visibilidad panorámica.';

    return {
      'atractivo_id': '11111111-1111-1111-1111-111111111111',
      'atractivo_nombre': nombreAtractivo,
      'score': score,
      'nivel': nivel,
      'recommendation_text': texto,
      'consejos': consejos,
      'source': 'gemini_engine_fallback',
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Lista de recomendaciones para múltiples atractivos del catálogo de Ica
  List<Map<String, dynamic>> obtenerCatalogoRecomendacionesOffline() {
    return [
      {
        'atractivo_id': '1',
        'atractivo_nombre': 'Oasis de Huacachina',
        'score': 0.95,
        'nivel': 'excelente',
        'recommendation_text': 'Condiciones excelentes para sandboarding y paseo en carros tubulares en las dunas.',
        'consejos': [
          'Usar lentes de sol para la arena',
          'Bloqueador solar FPS 50+',
          'Ideal entre 3:30 PM y 6:00 PM para ver el atardecer',
        ],
      },
      {
        'atractivo_id': '2',
        'atractivo_nombre': 'Islas Ballestas (Paracas)',
        'score': 0.88,
        'nivel': 'excelente',
        'recommendation_text': 'Mar tranquilo y viento suave en la bahía de Paracas. Excelente avistamiento de fauna marina.',
        'consejos': [
          'Llevar cortaviento para el trayecto en lancha',
          'Embarcarse temprano (entre 8:00 AM y 10:00 AM)',
          'No tocar ni alimentar a los lobos marinos',
        ],
      },
      {
        'atractivo_id': '3',
        'atractivo_nombre': 'Bodega Tacama',
        'score': 0.92,
        'nivel': 'excelente',
        'recommendation_text': 'Ambiente soleado y temperatura templada para recorridos enológicos y cata de piscos.',
        'consejos': [
          'Ropa ligera y calzado cómodo',
          'Probar el tradicional pisco quebranta y vinos patrimoniales',
        ],
      },
      {
        'atractivo_id': '4',
        'atractivo_nombre': 'Cañón de los Perdidos',
        'score': 0.80,
        'nivel': 'bueno',
        'recommendation_text': 'Desierto profundo con calor intenso al mediodía. Realizar la caminata temprano.',
        'consejos': [
          'Ir obligatoriamente con guía oficial y movilidad 4x4',
          'Llevar al menos 2 litros de agua por persona',
          'Calzado de trekking con buen agarre',
        ],
      },
    ];
  }
}
