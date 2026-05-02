import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/widgets/ahvi_home_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COLORS  (light-mode palette)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  // Backgrounds — matches BaseTheme.lightBgPrimary / lightBgSecondary
  static const Color bg          = Color(0xFFFFFFFF);
  static const Color bgMid       = Color(0xFFF4F7FF);
  static const Color bgEnd       = Color(0xFFEEF3FF);

  // Text
  static const Color text        = Color(0xFF1A1D26); // BaseTheme.lightText
  static const Color muted       = Color(0xFF66708A); // BaseTheme.lightMuted

  // Accent — coolBlue palette (AccentPalette)
  static const Color accent      = Color(0xFF6B91FF); // AccentPalette.primary
  static const Color accent2     = Color(0xFF8D7DFF); // AccentPalette.secondary

  // Shimmer — dark on light is more readable
  static const Color shimmerBase = Color(0xCC3A4A7A);
  static const Color shimmerHi   = Color(0xFF1A1D26);

  // Glow orb — soft accent tint, reduced alpha for light bg
  static const Color orbInner    = Color(0x336B91FF);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PARTICLE MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final double x, y, size, speed, phase, drift, opacity;
  const _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.phase,
    required this.drift, required this.opacity,
  });
}

List<_Particle> _buildParticles(int count, math.Random rng) =>
    List.generate(count, (_) => _Particle(
      x:       rng.nextDouble(),
      y:       rng.nextDouble(),
      size:    1.5 + rng.nextDouble() * 2.5,
      speed:   0.06 + rng.nextDouble() * 0.10,
      phase:   rng.nextDouble() * math.pi * 2,
      drift:   0.02 + rng.nextDouble() * 0.04,
      opacity: 0.15 + rng.nextDouble() * 0.35, // slightly lower on light bg
    ));

// ─────────────────────────────────────────────────────────────────────────────
//  PAINTERS
// ─────────────────────────────────────────────────────────────────────────────
class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t, fadeIn;
  _ParticlesPainter({required this.particles, required this.t, required this.fadeIn});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final rawY     = p.y - p.speed * t;
      final yNorm    = rawY - rawY.floor();
      final xNorm    = p.x + p.drift * math.sin(t * math.pi * 2 + p.phase);
      final edgeFade = yNorm < 0.1 ? yNorm / 0.1 : 1.0;
      canvas.drawCircle(
        Offset(xNorm * size.width, yNorm * size.height),
        p.size,
        Paint()..color = _C.accent.withValues(alpha: p.opacity * fadeIn * edgeFade),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => true;
}

class _GridPainter extends CustomPainter {
  final double opacity;
  const _GridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.accent.withValues(alpha: opacity)
      ..strokeWidth = 0.4;
    for (int c = 1; c < 6; c++) {
      final x = size.width * c / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int r = 1; r < 10; r++) {
      final y = size.height * r / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.opacity != opacity;
}

class _RingPainter extends CustomPainter {
  final double pulse, fadeIn;
  const _RingPainter({required this.pulse, required this.fadeIn});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final radius = (80.0 + i * 38.0) + pulse * 10.0 * (i + 1);
      final alpha  = (0.14 - i * 0.03) * fadeIn * (1.0 - pulse * 0.3); // softer on light bg
      canvas.drawCircle(center, radius,
        Paint()
          ..color = _C.accent.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 - i * 0.2,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SPLASH SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _staggerCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _ringCtrl;

  late final Animation<double> _bgReveal;
  late final Animation<double> _gridFade;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _subFade;
  late final Animation<Offset>  _subSlide;
  late final Animation<double> _tagFade;
  late final Animation<Offset>  _tagSlide;
  late final Animation<double> _dotsFade;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;
  late final List<_Particle> _particles;

  static const _entranceDuration = Duration(milliseconds: 1800);
  static const _glowDuration     = Duration(milliseconds: 3200);
  static const _shimmerDuration  = Duration(milliseconds: 2600);
  static const _particleDuration = Duration(milliseconds: 8000);
  static const _ringDuration     = Duration(milliseconds: 2800);
  static const _autoNavDelay     = Duration(milliseconds: 5500);

  @override
  void initState() {
    super.initState();

    _particles = _buildParticles(45, math.Random(42));

    _staggerCtrl = AnimationController(vsync: this, duration: _entranceDuration);

    _bgReveal = Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic)));
    _gridFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.05, 0.40, curve: Curves.easeOut)));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.10, 0.55, curve: Curves.easeOutCubic)));
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.10, 0.55, curve: Curves.easeOutBack)));
    _subFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.45, 0.80, curve: Curves.easeOutCubic)));
    _subSlide = Tween<Offset>(begin: const Offset(0, 0.40), end: Offset.zero).animate(
        CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.45, 0.80, curve: Curves.easeOutCubic)));
    _tagFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.65, 0.95, curve: Curves.easeOut)));
    _tagSlide = Tween<Offset>(begin: const Offset(0, 0.60), end: Offset.zero).animate(
        CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.65, 0.95, curve: Curves.easeOutCubic)));
    _dotsFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.80, 1.00, curve: Curves.easeOut)));

    _glowCtrl = AnimationController(vsync: this, duration: _glowDuration)..repeat(reverse: true);
    _glowScale = Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _glowOpacity = Tween<double>(begin: 0.12, end: 0.28).animate( // reduced for light bg
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(vsync: this, duration: _shimmerDuration)..repeat();
    _particleCtrl = AnimationController(vsync: this, duration: _particleDuration)..repeat();
    _ringCtrl = AnimationController(vsync: this, duration: _ringDuration)..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      _staggerCtrl.forward();
    });
    Future.delayed(_autoNavDelay, () {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    _shimmerCtrl.dispose();
    _particleCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // dark icons on light status bar
      child: Scaffold(
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _staggerCtrl, _glowCtrl, _shimmerCtrl,
            _particleCtrl, _ringCtrl,
          ]),
          builder: (context, _) => Transform.scale(
            scale: _bgReveal.value,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.bg, _C.bgMid, _C.bgEnd], // white → EEF3FF
                  stops: [0.0, 0.50, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(
                      painter: _GridPainter(opacity: 0.06 * _gridFade.value))),
                  Positioned.fill(child: CustomPaint(
                      painter: _ParticlesPainter(
                          particles: _particles, t: _particleCtrl.value,
                          fadeIn: _logoFade.value))),
                  Positioned.fill(child: CustomPaint(
                      painter: _RingPainter(
                          pulse: _ringCtrl.value, fadeIn: _logoFade.value))),
                  SafeArea(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(child: _buildBrandSection()),
                        Positioned(
                          bottom: 48,
                          left: 0,
                          right: 0,
                          child: Center(child: _buildBottomSection()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow orb behind the logo
            Transform.scale(
              scale: _glowScale.value,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _C.orbInner.withValues(
                        alpha: _glowOpacity.value * _logoFade.value),
                    const Color(0x00000000),
                  ]),
                ),
              ),
            ),
            // Ring painter overlay
            SizedBox(
              width: 220,
              height: 220,
              child: CustomPaint(
                painter: _RingPainter(
                  pulse: _ringCtrl.value,
                  fadeIn: _logoFade.value,
                ),
              ),
            ),
            // AhviHomeText — same logo as home screen
            Opacity(
              opacity: _logoFade.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: AhviHomeText(
                  color: _C.text, // dark text on light background
                  fontSize: 52,
                  letterSpacing: 10.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Subtitle: "Your personal AI assistant"
        SlideTransition(
          position: _subSlide,
          child: Opacity(
            opacity: _subFade.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your personal ',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (b) => const LinearGradient(
                    colors: [_C.accent, _C.accent2],
                  ).createShader(b),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const Icon(Icons.auto_awesome_rounded,
                    color: _C.accent2, size: 9),
                const Text(
                  ' assistant',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return SlideTransition(
      position: _tagSlide,
      child: Opacity(
        opacity: _tagFade.value,
        child: Column(
          children: [
            // Tagline: "Style. Plan. Prep."
            const Text(
              'Style. Plan. Prep.',
              style: TextStyle(
                color: _C.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 28),
            Opacity(opacity: _dotsFade.value, child: _buildShimmerBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBar() {
    // AI pulse dots — 5 nodes that light up sequentially
    final t = _shimmerCtrl.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final phase = (t * 5 - i) % 1.0;
        final glow  = phase < 0.3 ? (phase / 0.3) : phase < 0.6 ? 1.0 - ((phase - 0.3) / 0.3) : 0.0;
        final size  = 4.0 + glow * 4.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(_C.accent.withValues(alpha: 0.30),
                  _C.accent2, glow),
              boxShadow: glow > 0.1 ? [
                BoxShadow(
                  color: _C.accent.withValues(alpha: glow * 0.5), // softer shadow on light bg
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
        );
      }),
    );
  }
}