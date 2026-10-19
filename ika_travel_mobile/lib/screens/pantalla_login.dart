import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../services/auth_service.dart';
import 'main_scaffold.dart';
import 'pantalla_registro.dart';

/// Pantalla de inicio de sesión con flujo completo de autenticación.
class PantallaLogin extends StatefulWidget {
  final bool abrirComoModal;

  const PantallaLogin({super.key, this.abrirComoModal = false});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _recordarme = true;
  String? _mensajeError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _mensajeError = null);

    final resultado = await AuthService().login(
      _emailController.text,
      _passwordController.text,
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

      if (widget.abrirComoModal) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScaffold()),
        );
      }
    } else {
      setState(() => _mensajeError = resultado.mensaje);
    }
  }

  Future<void> _ingresarComoInvitado() async {
    await AuthService().ingresarComoInvitado();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ingresaste en modo invitado. ¡Disfruta tu viaje!'),
        backgroundColor: AppColores.marronOscuro,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (widget.abrirComoModal) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    }
  }

  void _llenarCredencialesDemo() {
    _emailController.text = 'turista@ikatravel.pe';
    _passwordController.text = 'Ika2026*';
    setState(() => _mensajeError = null);
  }

  void _mostrarDialogoRecuperarPassword() {
    final correoRecuperacion = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TemaApp.tarjeta(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Recuperar contraseña',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: TemaApp.texto(ctx),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa tu correo registrado y te enviaremos un enlace seguro para restablecer tu contraseña.',
                style: TextStyle(
                  fontSize: 13,
                  color: TemaApp.textoSecundario(ctx),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: correoRecuperacion,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaBoton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enlace enviado a ${correoRecuperacion.text}. Revisa tu bandeja.',
                    ),
                    backgroundColor: AppColores.marronOscuro,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Enviar enlace'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorFondo = TemaApp.fondo(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final colorTexto = TemaApp.texto(context);
    final colorTextoSec = TemaApp.textoSecundario(context);

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: AuthService().cargandoNotifier,
          builder: (context, cargando, _) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logotipo e Identidad
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColores.naranjaBoton.withOpacity(0.12),
                        ),
                        child: const Icon(
                          Icons.travel_explore,
                          size: 58,
                          color: AppColores.naranjaBoton,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ika Travel',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colorTexto,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tu compañero inteligente de viaje en Ica',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorTextoSec,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Tarjeta de Formulario
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Campo Correo
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
                                  return 'Ingresa tu correo electrónico';
                                }
                                if (!val.contains('@') || !val.contains('.')) {
                                  return 'Ingresa un correo electrónico válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Campo Contraseña
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
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
                                  return 'Ingresa tu contraseña';
                                }
                                if (val.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            // Recordarme y Olvidé Contraseña
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _recordarme,
                                        activeColor: AppColores.naranjaBoton,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        onChanged: (val) {
                                          setState(() => _recordarme = val ?? true);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Recordarme',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorTextoSec,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: _mostrarDialogoRecuperarPassword,
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColores.naranjaBoton,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Mensaje de Error
                            if (_mensajeError != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
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

                            const SizedBox(height: 18),

                            // Botón de Iniciar Sesión
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColores.naranjaBoton,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor:
                                      AppColores.naranjaBoton.withOpacity(0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: cargando ? null : _iniciarSesion,
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
                                        'Iniciar Sesión',
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

                      const SizedBox(height: 18),

                      // Botón Cuenta Demo
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColores.naranjaBoton.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(
                          Icons.vpn_key_outlined,
                          size: 18,
                          color: AppColores.naranjaBoton,
                        ),
                        label: const Text(
                          'Cargar cuenta demo de prueba',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColores.naranjaBoton,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _llenarCredencialesDemo,
                      ),

                      const SizedBox(height: 16),

                      // Continuar como Invitado
                      TextButton.icon(
                        icon: const Icon(
                          Icons.person_outline,
                          size: 18,
                          color: Colors.grey,
                        ),
                        label: const Text(
                          'Continuar como invitado',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        onPressed: cargando ? null : _ingresarComoInvitado,
                      ),

                      const SizedBox(height: 16),

                      // Registro de cuenta nueva
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿No tienes una cuenta? ',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorTextoSec,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PantallaRegistro(),
                                ),
                              );
                            },
                            child: const Text(
                              'Regístrate aquí',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColores.naranjaBoton,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
