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

  /// Ids de los atractivos que el usuario tiene en favoritos en el servidor.
  ///
  /// Sirve para recuperar los favoritos al iniciar sesión (en otro teléfono o
  /// tras reinstalar la app). El endpoint solo devuelve `attraction_id`, así
  /// que el nombre y la imagen se buscan después en el catálogo.
  Future<List<String>> obtenerIdsFavoritos() async {
    if (!_sesionValida()) return const [];

    try {
      final res = await _apiClient.get('/users/me/favorites');
      if (res is List) {
        return res
            .map((item) {
              if (item is Map) return item['attraction_id']?.toString() ?? '';
              return item.toString();
            })
            .where((id) => id.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[FavoritesService] Error al listar favoritos remotos: $e');
    }
    return const [];
  }

  /// ¿Hay una sesión real (no invitado, no token offline) para llamar a la API?
  bool _sesionValida() {
    final usuario = AuthService().usuarioActual;
    final token = usuario?.token;
    return usuario != null &&
        !usuario.esInvitado &&
        token != null &&
        token.isNotEmpty &&
        !token.startsWith('jwt_offline');
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
