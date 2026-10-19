/// Modelo de Usuario para la autenticación y perfil en Ika Travel.
/// Compatible con el esquema UserResponse y TokenResponse del backend FastAPI.
class UsuarioModelo {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role; // tourist, guide, operator, admin
  final String preferredLanguage; // es, en
  final List<String> preferences;
  final String? token;
  final bool esInvitado;

  const UsuarioModelo({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.role = 'tourist',
    this.preferredLanguage = 'es',
    this.preferences = const [],
    this.token,
    this.esInvitado = false,
  });

  /// Crea un perfil de usuario en modo invitado (navegación sin registro)
  factory UsuarioModelo.invitado() {
    return const UsuarioModelo(
      id: 'guest_local',
      email: 'invitado@ikatravel.pe',
      fullName: 'Viajero Invitado',
      role: 'guest',
      esInvitado: true,
    );
  }

  /// Crea un perfil de usuario demo para pruebas rápidas
  factory UsuarioModelo.demo() {
    return const UsuarioModelo(
      id: 'demo_user_123',
      email: 'turista@ikatravel.pe',
      fullName: 'Camila Rossi',
      phone: '+51 956 789 012',
      role: 'tourist',
      token: 'demo_jwt_token_ikatravel',
      preferences: ['aventura', 'vino_pisco', 'naturaleza'],
      esInvitado: false,
    );
  }

  UsuarioModelo copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? role,
    String? preferredLanguage,
    List<String>? preferences,
    String? token,
    bool? esInvitado,
  }) {
    return UsuarioModelo(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferences: preferences ?? this.preferences,
      token: token ?? this.token,
      esInvitado: esInvitado ?? this.esInvitado,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'preferred_language': preferredLanguage,
      'preferences': preferences,
      'token': token,
      'es_invitado': esInvitado,
    };
  }

  factory UsuarioModelo.fromJson(Map<String, dynamic> json) {
    return UsuarioModelo(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'tourist',
      preferredLanguage: json['preferred_language']?.toString() ?? 'es',
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      token: json['token']?.toString() ?? json['access_token']?.toString(),
      esInvitado: json['es_invitado'] == true,
    );
  }

  /// Iniciales del usuario para mostrar en avatar circular
  String get iniciales {
    if (fullName.trim().isEmpty) return 'IT';
    final partes = fullName.trim().split(RegExp(r'\s+'));
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }
}
