import 'package:flutter/material.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_typography.dart';

class FooterWordmark extends StatelessWidget {
  const FooterWordmark({super.key, this.showWhiskrs = true});

  final bool showWhiskrs;

  @override
  Widget build(BuildContext context) {
    final rightSide = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 20, height: 1, color: OobColors.oobNavy),
            const SizedBox(width: 10),
            Text(
              'OUT OF',
              style: OobTypography.wordmark.copyWith(
                fontSize: 16,
                letterSpacing: 0.64,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 20, height: 1, color: OobColors.oobNavy),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'BOREDOM',
          style: OobTypography.wordmark.copyWith(
            fontSize: 20,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );

    if (!showWhiskrs) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: rightSide,
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "WHISK'RS",
              style: OobTypography.wordmarkItalic,
            ),
            const SizedBox(width: 16),
            Container(
              width: 1,
              height: 40,
              color: OobColors.oobNavy.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 16),
            rightSide,
          ],
        ),
      ),
    );
  }
}
