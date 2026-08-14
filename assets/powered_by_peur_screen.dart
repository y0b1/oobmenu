// PoweredByPeurScreen — portrait "Powered by PEUR" end card.
//
// Setup: add the wordmark font to pubspec.yaml
//   fonts:
//     - family: Inversionz
//       fonts:
//         - asset: assets/fonts/Inversionz.otf
//     - family: IBMPlexMono
//       fonts:
//         - asset: assets/fonts/IBMPlexMono-Regular.ttf
//
// Usage: Navigator.push(context, MaterialPageRoute(builder: (_) => const PoweredByPeurScreen()));
// Pass onFinished to continue once the card has held.

import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color kPeurNavy = Color(0xFF0A206A);
const Color kPeurSlate = Color(0xFF7C85A3);

class PoweredByPeurScreen extends StatefulWidget {
  const PoweredByPeurScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<PoweredByPeurScreen> createState() => _PoweredByPeurScreenState();
}

class _PoweredByPeurScreenState extends State<PoweredByPeurScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 6400);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _total)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onFinished?.call();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Authored seconds -> 0..1 progress with an easing curve.
  double _span(double t, double start, double end, Curve curve) {
    if (end <= start) return t >= end ? 1 : 0;
    final raw = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * _total.inMilliseconds / 1000.0;

          final markIn = _span(t, 0.0, 0.5, Curves.easeOutSine);
          final markScale = 0.9 + 0.1 * _span(t, 0.0, 1.3, Curves.easeOutQuart);
          final r1 = 15.0 * _span(t, 0.10, 0.95, Curves.easeOutCubic);
          final r2 = 30.0 * _span(t, 0.25, 1.15, Curves.easeOutCubic);
          final r3 = 45.0 * _span(t, 0.40, 1.40, Curves.easeOutCubic);

          final labelIn = _span(t, 2.1, 2.65, Curves.easeOutSine);
          final labelY = 14.0 * (1 - _span(t, 2.1, 2.8, Curves.easeOutQuart));
          final wordIn = _span(t, 2.4, 3.0, Curves.easeOutSine);
          final wordY = 26.0 * (1 - _span(t, 2.4, 3.25, Curves.easeOutQuart));

          final ruleW = 300.0 * _span(t, 3.8, 4.7, Curves.easeOutQuart);
          final metaIn = _span(t, 4.15, 4.75, Curves.easeOutSine);

          return SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: markIn,
                    child: Transform.scale(
                      scale: markScale,
                      child: SizedBox.square(
                        dimension: 200,
                        child: CustomPaint(
                          painter: PeurMarkPainter(
                            rotations: [0, r1, r2, r3],
                            color: kPeurNavy,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),
                  Opacity(
                    opacity: labelIn,
                    child: Transform.translate(
                      offset: Offset(0, labelY),
                      child: const Text(
                        'POWERED BY',
                        style: TextStyle(
                          fontFamily: 'IBMPlexMono',
                          fontSize: 20,
                          letterSpacing: 6.8,
                          color: kPeurSlate,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: wordIn,
                    child: Transform.translate(
                      offset: Offset(0, wordY),
                      child: const Text(
                        'peur',
                        style: TextStyle(
                          fontFamily: 'Inversionz',
                          fontSize: 104,
                          height: 0.9,
                          letterSpacing: 2,
                          color: kPeurNavy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),
                  Container(width: ruleW, height: 2, color: kPeurNavy),
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: metaIn,
                    child: Column(
                      children: const [
                        Text(
                          'HELLO@PEUR.PH',
                          style: TextStyle(
                            fontFamily: 'IBMPlexMono',
                            fontSize: 15,
                            letterSpacing: 3,
                            color: kPeurSlate,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'DAVAO CITY',
                          style: TextStyle(
                            fontFamily: 'IBMPlexMono',
                            fontSize: 15,
                            letterSpacing: 3,
                            color: kPeurSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Draws the PEUR mark: four squares on one centre, dividing lines and the P
/// cut clear through the shape so the background shows through.
class PeurMarkPainter extends CustomPainter {
  PeurMarkPainter({required this.rotations, required this.color});

  /// Degrees for the three lower squares plus the solid top square.
  final List<double> rotations;
  final Color color;

  static const double _design = 200;
  static const Rect _box = Rect.fromLTWH(40, 40, 120, 120);

  Path _square(double degrees, double k) {
    final m = Matrix4.identity()
      ..scale(k, k)
      ..translate(100.0, 100.0)
      ..rotateZ(degrees * math.pi / 180)
      ..translate(-100.0, -100.0);
    return (Path()..addRect(_box)).transform(m.storage);
  }

  Path _letterP(double degrees, double k) {
    final m = Matrix4.identity()
      ..scale(k, k)
      ..translate(100.0, 100.0)
      ..rotateZ(degrees * math.pi / 180)
      ..scale(0.556, 0.556)
      ..translate(-72.0, -72.0);
    final p = Path()
      ..addRect(const Rect.fromLTWH(0, 0, 32, 144))
      ..addRect(const Rect.fromLTWH(0, 0, 144, 28))
      ..addRect(const Rect.fromLTWH(112, 0, 32, 88))
      ..addRect(const Rect.fromLTWH(0, 60, 144, 28));
    return p.transform(m.storage);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / _design;
    final bounds = Offset.zero & size;

    canvas.saveLayer(bounds, Paint());

    final fill = Paint()..color = color;
    for (final d in rotations.take(3)) {
      canvas.drawPath(_square(d, k), fill);
    }

    final cut = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * k;
    for (final d in rotations.take(3)) {
      canvas.drawPath(_square(d, k), cut);
    }

    canvas.drawPath(_square(rotations.last, k), fill);
    canvas.drawPath(
      _letterP(rotations.last, k),
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(PeurMarkPainter old) =>
      old.rotations != rotations || old.color != color;
}
