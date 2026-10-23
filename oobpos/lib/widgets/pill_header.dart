import 'package:flutter/material.dart';
import '../theme/oob_colors.dart';

class PillHeader extends StatelessWidget {
  const PillHeader({
    super.key,
    required this.child,
    this.color = OobColors.oobNavy,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}
