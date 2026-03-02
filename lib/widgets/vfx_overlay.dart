import 'dart:math';
import 'package:flutter/material.dart';

class VfxOverlay extends StatefulWidget {
  final Widget child;

  const VfxOverlay({Key? key, required this.child}) : super(key: key);

  static VfxOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<VfxOverlayState>();
  }

  @override
  VfxOverlayState createState() => VfxOverlayState();
}

class VfxOverlayState extends State<VfxOverlay> with TickerProviderStateMixin {
  // Screen Shake
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Lightning Flash
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  // Bomb Explosion
  final List<_Particle> _bombParticles = [];
  late AnimationController _bombController;

  @override
  void initState() {
    super.initState();

    // Shake
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _shakeController,
      curve: _ShakeCurve(),
    ));

    // Flash
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _flashAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _flashController,
      curve: Curves.fastOutSlowIn,
    ));
    _flashController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _flashController.reverse();
      }
    });

    // Bomb
    _bombController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _bombController.addListener(() {
      setState(() {
        for (var p in _bombParticles) {
          p.update();
        }
      });
    });
    _bombController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _bombParticles.clear());
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _flashController.dispose();
    _bombController.dispose();
    super.dispose();
  }

  void triggerScreenShake() {
    _shakeController.forward(from: 0);
  }

  void playLightningFlash() {
    _flashController.forward(from: 0);
  }

  void playBombExplosion() {
    final random = Random();
    final center = MediaQuery.of(context).size / 2;
    
    setState(() {
      _bombParticles.clear();
      for (int i = 0; i < 40; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final speed = random.nextDouble() * 5 + 2;
        _bombParticles.add(_Particle(
          x: center.width,
          y: center.height,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: random.nextBool() ? Colors.orange : Colors.redAccent,
          size: random.nextDouble() * 8 + 4,
        ));
      }
    });
    _bombController.forward(from: 0);
    triggerScreenShake();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _ShakeCurve extends Curve {
  @override
  double transform(double t) {
    // Decaying sine wave
    return sin(t * 10 * pi) * (1 - t);
  }
}

class _Particle {
  double x, y, vx, vy;
  double opacity = 1.0;
  final Color color;
  final double size;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });

  void update() {
    x += vx;
    y += vy;
    vx *= 0.95; // Friction
    vy *= 0.95;
    opacity *= 0.9;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      if (p.opacity <= 0.01) continue;
      paint.color = p.color.withOpacity(p.opacity);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
