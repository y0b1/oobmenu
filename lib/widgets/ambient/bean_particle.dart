import 'dart:math';

class BeanParticle {
  BeanParticle({required Random random})
      : x = random.nextDouble(),
        y = -0.1 - random.nextDouble() * 0.2,
        size = 12 + random.nextDouble() * 10,
        speed = 0.0002 + random.nextDouble() * 0.0002,
        rotation = random.nextDouble() * 2 * pi,
        rotationSpeed = (random.nextDouble() - 0.5) * 0.002,
        alpha = 0.04 + random.nextDouble() * 0.04;

  double x;
  double y;
  double size;
  double speed;
  double rotation;
  double rotationSpeed;
  double alpha;

  bool get isDead => y > 1.2;

  void update(double dt) {
    y += speed * dt;
    rotation += rotationSpeed * dt;
  }
}
