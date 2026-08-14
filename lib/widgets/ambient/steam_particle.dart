import 'dart:math';

class SteamParticle {
  SteamParticle({required Random random})
      : x = random.nextDouble(),
        y = 0.8 + random.nextDouble() * 0.2,
        size = 20 + random.nextDouble() * 30,
        speed = 0.0003 + random.nextDouble() * 0.0004,
        alpha = 0.0,
        maxAlpha = 0.04 + random.nextDouble() * 0.08,
        drift = (random.nextDouble() - 0.5) * 0.0002;

  double x;
  double y;
  double size;
  double speed;
  double alpha;
  double maxAlpha;
  double drift;

  bool get isDead => y < -0.1 || alpha <= 0;

  void update(double dt) {
    y -= speed * dt;
    x += drift * dt;

    final life = 1.0 - ((0.8 - y) / 1.0).clamp(0.0, 1.0);
    if (life > 0.7) {
      alpha = maxAlpha * ((1.0 - life) / 0.3);
    } else if (life < 0.3) {
      alpha = maxAlpha * (life / 0.3);
    } else {
      alpha = maxAlpha;
    }
  }
}
