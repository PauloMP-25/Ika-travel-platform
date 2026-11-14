import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../config/idioma_manager.dart';
import '../config/traducciones.dart';
import '../config/traducciones_scope.dart';
import '../services/auth_service.dart';
import 'main_scaffold.dart';
import 'pantalla_login.dart';

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
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _aceptaTerminos = true;
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
        SnackBar(
          content: Text(context.tr('debes_aceptar_terminos')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _mensajeError = null);

    final idiomaActual = context.locale.languageCode;

    final resultado = await AuthService().registrar(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _nameController.text,
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text
          : null,
      idioma: idiomaActual,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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

    final currentLang = context.locale.languageCode;

    Widget _campo({
      required TextEditingController controller,
      required String label,
      String? hint,
      IconData? icono,
      Widget? sufijo,
      String? helper,
      TextInputType? keyboardType,
      bool obscure = false,
      TextCapitalization textCapitalization = TextCapitalization.none,
      String? Function(String?)? validator,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorTextoSec,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorFondo.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorTextoSec.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icono != null) ...[
                  Icon(icono, color: colorTextoSec, size: 22),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    keyboardType: keyboardType,
                    obscureText: obscure,
                    textCapitalization: textCapitalization,
                    validator: validator,
                    style: TextStyle(color: colorTexto, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: hint,
                      helperText: helper,
                      hintStyle: TextStyle(
                        color: colorTextoSec.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      helperStyle: TextStyle(
                        color: colorTextoSec.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                      suffixIcon: sufijo,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget _campoIdioma() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              context.tr('idioma_preferido'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorTextoSec,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorFondo.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorTextoSec.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.language, color: colorTextoSec, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: currentLang,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: TextStyle(color: colorTexto, fontSize: 15),
                    dropdownColor: colorTarjeta,
                    items: Traducciones.supportedLocales.map((loc) {
                      final nombre =
                          Traducciones.nombresIdioma[loc.languageCode] ??
                          loc.languageCode;
                      return DropdownMenuItem<String>(
                        value: loc.languageCode,
                        child: Text(
                          nombre,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorTexto, fontSize: 15),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != currentLang) {
                        cambiarIdioma(val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

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
          context.tr('crear_cuenta'),
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
                      context.tr('unete_ika'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('subtitulo_registro'),
                      style: TextStyle(fontSize: 13, color: colorTextoSec),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorTarjeta,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _campo(
                            controller: _nameController,
                            label: context.tr('nombre_completo'),
                            hint: context.tr('ej_juan_perez'),
                            icono: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return context.tr('ingresa_nombre');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // 👇 AQUÍ ESTABA EL PROBLEMA: hint hardcodeado
                          _campo(
                            controller: _emailController,
                            label: context.tr('correo_electronico'),
                            hint: context.tr('ej_correo'), // ✅ ahora traducido
                            icono: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return context.tr('ingresa_correo');
                              }
                              if (!val.contains('@') || !val.contains('.')) {
                                return context.tr('correo_invalido');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          _campo(
                            controller: _phoneController,
                            label: context.tr('telefono_opcional'),
                            hint: '+51 987 654 321',
                            icono: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),

                          _campoIdioma(),
                          const SizedBox(height: 14),

                          _campo(
                            controller: _passwordController,
                            label: context.tr('contrasena'),
                            helper: context.tr('minimo_8'),
                            icono: Icons.lock_outline,
                            obscure: _obscurePassword,
                            sufijo: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: colorTextoSec,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return context.tr('ingresa_contrasena');
                              }
                              if (val.length < 8) {
                                return context.tr('contrasena_corta');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          _campo(
                            controller: _confirmPasswordController,
                            label: context.tr('confirmar_contrasena'),
                            icono: Icons.lock_clock_outlined,
                            obscure: _obscureConfirmPassword,
                            sufijo: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: colorTextoSec,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (val) {
                              if (val != _passwordController.text) {
                                return context.tr('contrasenas_no_coinciden');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

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
                                    setState(
                                      () => _aceptaTerminos = val ?? true,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr('acepto_terminos'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorTextoSec,
                                  ),
                                ),
                              ),
                            ],
                          ),

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
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 18,
                                  ),
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
                                  : Text(
                                      context.tr('registrarme'),
                                      style: const TextStyle(
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
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr('ya_tienes_cuenta'),
                            style: TextStyle(
                              fontSize: 13,
                              color: colorTextoSec,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Reemplaza el registro por el login para que
                              // "iniciar sesión" lleve al formulario correcto
                              // (no de vuelta a la bienvenida).
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PantallaLogin(),
                                ),
                              );
                            },
                            child: Text(
                              context.tr('inicia_sesion'),
                              style: const TextStyle(
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
