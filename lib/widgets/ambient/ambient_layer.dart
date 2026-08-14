import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/oob_colors.dart';
import 'steam_particle.dart';
import 'bean_particle.dart';

enum AmbientType { steam, beans, mixed }

class AmbientLayer extends StatefulWidget {
  const AmbientLayer({super.key, required this.type});

  final AmbientType type;

  @override
  State<AmbientLayer> createState() => _AmbientLayerState();
}

class _AmbientLayerState extends State<AmbientLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _random = Random();
  final _steamParticles = <SteamParticle>[];
  final _beanParticles = <BeanParticle>[];
  double _lastTime = 0;
  double _steamSpawnTimer = 0;
  double _beanSpawnTimer = 0;

  int get _maxSteam {
    switch (widget.type) {
      case AmbientType.steam:
        return 12;
      case AmbientType.mixed:
        return 6;
      case AmbientType.beans:
        return 0;
    }
  }

  int get _maxBeans {
    switch (widget.type) {
      case AmbientType.beans:
        return 6;
      case AmbientType.mixed:
        return 3;
      case AmbientType.steam:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_tick);
  }

  void _tick() {
    final now = _controller.lastElapsedDuration?.inMilliseconds.toDouble() ?? 0;
    final dt = now - _lastTime;
    _lastTime = now;

    if (dt <= 0 || dt > 100) return;

    if (_maxSteam > 0) {
      _steamSpawnTimer += dt;
      if (_steamSpawnTimer > 1500 && _steamParticles.length < _maxSteam) {
        _steamParticles.add(SteamParticle(random: _random));
        _steamSpawnTimer = 0;
      }
      for (final p in _steamParticles) {
        p.update(dt);
      }
      _steamParticles.removeWhere((p) => p.isDead);
    }

    if (_maxBeans > 0) {
      _beanSpawnTimer += dt;
      if (_beanSpawnTimer > 2000 && _beanParticles.length < _maxBeans) {
        _beanParticles.add(BeanParticle(random: _random));
        _beanSpawnTimer = 0;
      }
      for (final p in _beanParticles) {
        p.update(dt);
      }
      _beanParticles.removeWhere((p) => p.isDead);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _AmbientPainter(
            steamParticles: _steamParticles,
            beanParticles: _beanParticles,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.steamParticles,
    required this.beanParticles,
  });

  final List<SteamParticle> steamParticles;
  final List<BeanParticle> beanParticles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in steamParticles) {
      final paint = Paint()
        ..color = OobColors.oobWhite.withValues(alpha: p.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.6);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(p.x * size.width, p.y * size.height),
          width: p.size * 1.5,
          height: p.size,
        ),
        paint,
      );
    }

    for (final p in beanParticles) {
      final paint = Paint()
        ..color = OobColors.oobNavyDeep.withValues(alpha: p.alpha);
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rotation);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => true;
}
