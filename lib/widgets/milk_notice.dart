import 'package:flutter/material.dart';
import '../state/availability.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_typography.dart';
import '../theme/oob_spacing.dart';

/// A small chip that surfaces a restricted milk selection ("DAIRY MILK ONLY" /
/// "OAT MILK ONLY") at the top of a tab. Renders nothing when both milks are
/// available.
class MilkNotice extends StatelessWidget {
  const MilkNotice({super.key, required this.milk});

  final MilkAvailability milk;

  @override
  Widget build(BuildContext context) {
    final notice = milk.notice;
    if (notice == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: OobSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: OobColors.oobOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(OobRadius.pill),
          border: Border.all(
            color: OobColors.oobOrange.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_drink_outlined,
              size: 18,
              color: OobColors.oobOrangeDeep,
            ),
            const SizedBox(width: 8),
            Text(
              notice,
              style: OobTypography.displayCaps.copyWith(
                color: OobColors.oobOrangeDeep,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
