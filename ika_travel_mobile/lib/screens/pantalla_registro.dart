import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../services/auth_service.dart';
import 'main_scaffold.dart';

/// Pantalla para crear una nueva cuenta en Ika Travel.
class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _aceptaTerminos = true;
  String _idiomaSeleccionado = 'es';
  String? _mensajeError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_aceptaTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones para continuar'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _mensajeError = null);

    final resultado = await AuthService().registrar(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _nameController.text,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text : null,
      idioma: _idiomaSeleccionado,
    );

    if (!mounted) return;

    if (resultado.exitoso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(resultado.mensaje)),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
        (route) => false,
      );
    } else {
      setState(() => _mensajeError = resultado.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorFondo = TemaApp.fondo(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSec = TemaApp.textoSecundario(context);

    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorTexto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Crear cuenta',
          style: TextStyle(
            color: colorTexto,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: AuthService().cargandoNotifier,
          builder: (context, cargando, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Únete a Ika Travel',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Regístrate para guardar tus rutas, pronósticos y recibir alertas inteligentes.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorTextoSec,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tarjeta con Campos
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorTarjeta,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre completo
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Nombre completo',
                              hintText: 'Ej. Juan Pérez',
                              prefixIcon: const Icon(Icons.person_outline),
                              filled: true,
                              fillColor: colorFondo.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingresa tu nombre completo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Correo
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'ejemplo@correo.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: colorFondo.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingresa tu correo';
                              }
                              if (!val.contains('@') || !val.contains('.')) {
                                return 'Ingresa un correo electrónico válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Teléfono (opcional)
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Teléfono (opcional)',
                              hintText: '+51 987 654 321',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              filled: true,
                              fillColor: colorFondo.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Idioma preferido
                          DropdownButtonFormField<String>(
                            value: _idiomaSeleccionado,
                            decoration: InputDecoration(
                              labelText: 'Idioma preferido',
                              prefixIcon: const Icon(Icons.language),
                              filled: true,
                              fillColor: colorFondo.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'es', child: Text('Español (ES)')),
                              DropdownMenuItem(value: 'en', child: Text('English (EN)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _idiomaSeleccionado = val);
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // Contraseña
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              helperText: 'Mínimo 8 caracteres',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: colorFondo.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Ingresa una contraseña';
                              }
                              if (val.length < 8) {
                                return 'La contraseña debe tener al menos 8 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Confirmar contraseña
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirmar contraseña',
                              prefixIcon: const Icon(Icons.lock_clock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: colorFondo.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              if (val != _passwordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Aceptación de términos
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _aceptaTerminos,
                                  activeColor: AppColores.naranjaBoton,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() => _aceptaTerminos = val ?? true);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Acepto los términos de servicio y políticas de privacidad de Ika Travel.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorTextoSec,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Error
                          if (_mensajeError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _mensajeError!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Botón Registrar
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.naranjaBoton,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: cargando ? null : _crearCuenta,
                              child: cargando
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Registrarme',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Ya tengo cuenta
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿Ya tienes una cuenta? ',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorTextoSec,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Inicia sesión',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColores.naranjaBoton,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
