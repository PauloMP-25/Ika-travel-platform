import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../config/traducciones_scope.dart';
import '../services/auth_service.dart';
import 'main_scaffold.dart';
import 'pantalla_registro.dart';

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
  bool _cargandoGoogle = false;

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      await _verificarPermisosYEntrar();
    } else {
      setState(() => _mensajeError = resultado.mensaje);
    }
  }

  Future<void> _iniciarConGoogle() async {
    setState(() {
      _cargandoGoogle = true;
      _mensajeError = null;
    });

    final resultado = await AuthService().loginConGoogle(
      preferredLanguage: context.locale.languageCode,
      aceptaPoliticaDatos: true,
    );

    if (!mounted) return;

    setState(() => _cargandoGoogle = false);

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

      await _verificarPermisosYEntrar();
    } else {
      setState(() => _mensajeError = resultado.mensaje);
    }
  }

  Future<void> _verificarPermisosYEntrar() async {
    bool gpsActivo = await Geolocator.isLocationServiceEnabled();
    if (!gpsActivo && mounted) {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: TemaApp.tarjeta(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColores.naranjaBoton,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('activar_gps_titulo'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: TemaApp.texto(ctx),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            context.tr('activar_gps_msg'),
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: TemaApp.textoSecundario(ctx),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('continuar_sin_gps')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaBoton,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx, true);
                await Geolocator.openLocationSettings();
              },
              child: Text(context.tr('activar_gps')),
            ),
          ],
        ),
      );
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (widget.abrirComoModal) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    }
  }

  void _mostrarDialogoRecuperarPassword() {
    final correoRecuperacion = TextEditingController(
      text: _emailController.text,
    );
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TemaApp.tarjeta(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.tr('recuperar_contrasena'),
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
                context.tr('recuperar_contrasena_msg'),
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
                  labelText: context.tr('correo_electronico'),
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
              child: Text(context.tr('cancelar')),
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
                      '${context.tr('enlace_enviado')} ${correoRecuperacion.text}',
                    ),
                    backgroundColor: AppColores.marronOscuro,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(context.tr('enviar_enlace')),
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
            final bool ocupado = cargando || _cargandoGoogle;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColores.naranjaBoton.withValues(
                            alpha: 0.12,
                          ),
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
                        context.tr('eslogan_login'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: colorTextoSec),
                      ),
                      const SizedBox(height: 28),

                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('iniciar_sesion'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: context.tr('correo_electronico'),
                                hintText: context.tr('ej_correo'),
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: colorFondo.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return context.tr('error_correo_vacio');
                                }
                                if (!val.contains('@') || !val.contains('.')) {
                                  return context.tr('error_correo_invalido');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: context.tr('contrasena'),
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
                                fillColor: colorFondo.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return context.tr('error_contrasena_vacia');
                                }
                                if (val.length < 6) {
                                  return context.tr('error_contrasena_corta');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _recordarme,
                                        activeColor: AppColores.naranjaBoton,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setState(
                                            () => _recordarme = val ?? true,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.tr('recordarme'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorTextoSec,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: _mostrarDialogoRecuperarPassword,
                                  child: Text(
                                    context.tr('olvidaste_contrasena'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColores.naranjaBoton,
                                    ),
                                  ),
                                ),
                              ],
                            ),

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
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
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

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColores.naranjaBoton,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: AppColores.naranjaBoton
                                      .withValues(alpha: 0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: ocupado ? null : _iniciarSesion,
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
                                        context.tr('iniciar_sesion'),
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

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: colorTextoSec.withValues(alpha: 0.3),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              context.tr('o'),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorTextoSec,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: colorTextoSec.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: colorTarjeta,
                            side: BorderSide(
                              color: colorTextoSec.withValues(alpha: 0.25),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _cargandoGoogle
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColores.naranjaBoton,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 22,
                                  width: 22,
                                ),
                          label: Text(
                            _cargandoGoogle
                                ? context.tr('iniciando_google')
                                : context.tr('iniciar_con_google'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorTexto,
                            ),
                          ),
                          onPressed: ocupado ? null : _iniciarConGoogle,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr('no_tienes_cuenta'),
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
                            child: Text(
                              context.tr('registrate_aqui'),
                              style: const TextStyle(
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
