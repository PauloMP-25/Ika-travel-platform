import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_service.dart';

class FavoritesService {
  final ApiClient _apiClient;

  FavoritesService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Alterna el estado favorito de un atractivo en el backend si hay ID disponible
  Future<bool?> toggleRemoteFavorite(String attractionId) async {
    // Si no es un UUID válido (ej. IDs semilla '1', '2'), solo manejamos localmente
    if (attractionId.length < 32) return null;

    final usuario = AuthService().usuarioActual;
    final token = usuario?.token;
    if (usuario == null ||
        usuario.esInvitado ||
        token == null ||
        token.isEmpty ||
        token.startsWith('jwt_offline')) {
      return null;
    }

    try {
      final res = await _apiClient.post(
        '/catalog/attractions/$attractionId/favorite',
        body: {},
      );
      if (res is Map<String, dynamic> && res.containsKey('is_favorite')) {
        return res['is_favorite'] as bool;
      }
    } catch (e) {
      debugPrint('[FavoritesService] Error al sincronizar favorito remoto: $e');
    }
    return null;
  }

  /// Verifica si el atractivo está marcado como favorito en el backend
  Future<bool> checkIsFavorite(String attractionId) async {
    if (attractionId.length < 32) return false;

    final usuario = AuthService().usuarioActual;
    final token = usuario?.token;
    if (usuario == null ||
        usuario.esInvitado ||
        token == null ||
        token.isEmpty ||
        token.startsWith('jwt_offline')) {
      return false;
    }

    try {
      final res = await _apiClient.get('/catalog/attractions/$attractionId/is-favorite');
      if (res is bool) return res;
      if (res is Map<String, dynamic> && res.containsKey('is_favorite')) {
        return res['is_favorite'] as bool;
      }
    } catch (e) {
      debugPrint('[FavoritesService] Error al consultar favorito: $e');
    }
    return false;
  }
}
