import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_typography.dart';
import '../utils/peso.dart';

class PowderCard extends StatelessWidget {
  const PowderCard({
    super.key,
    required this.kind,
    required this.powders,
  });

  final PowderKind kind;
  final List<PowderOption> powders;

  @override
  Widget build(BuildContext context) {
    final color = kind == PowderKind.oobBlend
        ? OobColors.oobOrange
        : OobColors.oobNavy;
    final title = kind == PowderKind.oobBlend ? 'OOB Blend' : 'Tsuki';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: color,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: OobTypography.bodyBold.copyWith(
              color: OobColors.oobWhite,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 24),
          for (final powder in powders) ...[
            Text(
              formatPeso(powder.pricePhp),
              style: OobTypography.price.copyWith(
                color: OobColors.oobWhite,
                fontSize: 19,
              ),
            ),
            if (powder != powders.last) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
