import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiClient {
  // En Android Emulator 10.0.2.2 es localhost de la máquina host.
  // En dispositivo físico, Linux o Web se usa 127.0.0.1 o variable de entorno.
  static String get baseUrl {
    const customHost = String.fromEnvironment('API_BASE_URL');
    if (customHost.isNotEmpty) {
      return customHost;
    }
    const apiUrl = String.fromEnvironment('API_URL');
    if (apiUrl.isNotEmpty) {
      return apiUrl.endsWith('/api/v1') ? apiUrl : '$apiUrl/api/v1';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api/v1';
      }
    } catch (_) {
      // Entornos web o de testing donde Platform no aplica
    }
    return 'https://dreary-flap-stole.ngrok-free.dev/api/v1';
  }

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': 'es-PE,es;q=0.9',
        ...?headers,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw HttpException(
        'Error ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Language': 'es-PE,es;q=0.9',
        ...?headers,
      },
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw HttpException(
        'Error ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }
  }
}
