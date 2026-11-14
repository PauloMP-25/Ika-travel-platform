import 'dart:async';
import 'package:flutter/material.dart';

import '../config/tema.dart';
import 'pantalla_login.dart';
import 'pantalla_registro.dart';

/// Pantalla de bienvenida (onboarding) animada con paleta CLARA.
///
/// Reinterpreta el concepto del onboarding oscuro en tonos luminosos (arena,
/// turquesa y naranja suaves) para no cansar la vista. Presenta la marca y un
/// carrusel de 3 beneficios con auto-avance, y recién al pulsar "Comenzar" o
/// "Ya tengo una cuenta" aparece el formulario de correo y contraseña.
class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _SlideData {
  final String kick;
  final String titulo;
  final String cuerpo;
  final IconData icono;
  final Color color;
  const _SlideData({
    required this.kick,
    required this.titulo,
    required this.cuerpo,
    required this.icono,
    required this.color,
  });
}

class _PantallaBienvenidaState extends State<PantallaBienvenida>
    with TickerProviderStateMixin {
  static const Color _violeta = Color(0xFF7C6FF0);

  final List<_SlideData> _slides = const [
    _SlideData(
      kick: 'CLIMA EN VIVO',
      titulo: 'El clima manda el plan',
      cuerpo:
          'Temperatura, viento y UV de Huacachina y Paracas para elegir el '
          'mejor momento.',
      icono: Icons.wb_sunny_rounded,
      color: AppColores.naranjaBoton,
    ),
    _SlideData(
      kick: 'MAPA Y RUTAS',
      titulo: 'Llega sin perderte',
      cuerpo:
          'Dunas, viñedos de pisco e Islas Ballestas con distancias y tiempos '
          'claros.',
      icono: Icons.place_rounded,
      color: AppColores.turquesaOasis,
    ),
    _SlideData(
      kick: 'TRADUCTOR Y SOS',
      titulo: 'Seguro y entendido',
      cuerpo:
          'Traduce por voz al instante y envía auxilio con tu ubicación en un '
          'toque.',
      icono: Icons.shield_rounded,
      color: _violeta,
    ),
  ];

  static const Duration _duracionSlide = Duration(milliseconds: 4600);

  final PageController _pageController = PageController();
  late final AnimationController _entradaCtrl;
  late final AnimationController _flotarCtrl;
  late final AnimationController _progresoCtrl;
  Timer? _timer;
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _entradaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _flotarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _progresoCtrl = AnimationController(vsync: this, duration: _duracionSlide);
    _iniciarAutoAvance();
  }

  void _iniciarAutoAvance() {
    _progresoCtrl
      ..reset()
      ..forward();
    _timer?.cancel();
    _timer = Timer.periodic(_duracionSlide, (_) {
      final siguiente = (_indice + 1) % _slides.length;
      _pageController.animateToPage(
        siguiente,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _entradaCtrl.dispose();
    _flotarCtrl.dispose();
    _progresoCtrl.dispose();
    super.dispose();
  }

  void _irALogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
    );
  }

  void _irARegistro() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PantallaRegistro()),
    );
  }

  Animation<double> _curva(double inicio, double fin) {
    return CurvedAnimation(
      parent: _entradaCtrl,
      curve: Interval(inicio, fin, curve: Curves.easeOutCubic),
    );
  }

  Widget _apareciendo(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 18),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo claro con orbes suaves
          const Positioned.fill(child: _FondoClaro()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _apareciendo(_curva(0.0, 0.5), _marca()),
                  const SizedBox(height: 10),
                  _apareciendo(_curva(0.15, 0.6), _tagline()),
                  const SizedBox(height: 18),
                  Expanded(
                    child: _apareciendo(_curva(0.3, 0.8), _carrusel()),
                  ),
                  const SizedBox(height: 14),
                  _apareciendo(_curva(0.5, 1.0), _botones()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _marca() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColores.naranjaBoton.withValues(alpha: 0.35),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/logo_ika.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 14),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColores.naranjaBoton, AppColores.turquesaOasis],
          ).createShader(bounds),
          child: const Text(
            'Ika Travel',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tagline() {
    return const Text(
      'Tu compañero inteligente de viaje por el desierto y el mar de Ica.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13.5,
        height: 1.5,
        color: AppColores.grisTexto,
      ),
    );
  }

  Widget _carrusel() {
    return Column(
      children: [
        // Barras de progreso
        Row(
          children: List.generate(_slides.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == _slides.length - 1 ? 0 : 6),
                child: _barraProgreso(i),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) {
              setState(() => _indice = i);
              _iniciarAutoAvance();
            },
            itemBuilder: (context, i) => _tarjetaSlide(_slides[i]),
          ),
        ),
        const SizedBox(height: 14),
        // Puntos
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final activo = i == _indice;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3.5),
              width: activo ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: activo
                    ? const LinearGradient(colors: [
                        AppColores.naranjaBoton,
                        AppColores.turquesaOasis
                      ])
                    : null,
                color: activo ? null : Colors.black.withValues(alpha: 0.14),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _barraProgreso(int i) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 3,
        color: Colors.black.withValues(alpha: 0.10),
        child: AnimatedBuilder(
          animation: _progresoCtrl,
          builder: (context, _) {
            double factor;
            if (i < _indice) {
              factor = 1.0;
            } else if (i == _indice) {
              factor = _progresoCtrl.value;
            } else {
              factor = 0.0;
            }
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColores.naranjaBoton,
                    AppColores.turquesaOasis
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tarjetaSlide(_SlideData s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            s.color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: s.color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: s.color.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono con vida (flota suavemente), relleno vívido para contraste
          AnimatedBuilder(
            animation: _flotarCtrl,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -5 * _flotarCtrl.value),
              child: child,
            ),
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    s.color,
                    Color.lerp(s.color, Colors.white, 0.3)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: s.color.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(s.icono, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              s.kick,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w800,
                color: s.color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.15,
              color: AppColores.marronOscuro,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.cuerpo,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColores.grisTexto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botones() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _irARegistro,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ).copyWith(
              elevation: WidgetStateProperty.all(0),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB44D), AppColores.naranjaBoton],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColores.naranjaBoton.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                alignment: Alignment.center,
                height: 54,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Comenzar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _irALogin,
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13.5, color: AppColores.grisTexto),
              children: [
                TextSpan(text: 'Ya tengo una cuenta · '),
                TextSpan(
                  text: 'Entrar',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColores.marronOscuro,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fondo claro con orbes de color difuminados (sutiles, no cansan la vista).
class _FondoClaro extends StatelessWidget {
  const _FondoClaro();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFDFA), AppColores.arenaFondo],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          _orbe(220, AppColores.naranjaBoton, 0.14, left: -60, top: -40),
          _orbe(200, AppColores.turquesaOasis, 0.12, right: -50, top: 120),
          _orbe(240, const Color(0xFF7C6FF0), 0.10, left: -40, bottom: -60),
        ],
      ),
    );
  }

  Widget _orbe(double size, Color color, double opacity,
      {double? left, double? top, double? right, double? bottom}) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
