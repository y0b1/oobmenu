import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../state/menu_state.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_typography.dart';
import 'powder_card.dart';

class PowderGrid extends ConsumerWidget {
  const PowderGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuStateProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level labels (left ~50%)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                _levelLabel('Level 1 ', '(Light)'),
                const SizedBox(height: 18),
                _levelLabel('Level 2 ', '(Balanced)'),
                const SizedBox(height: 18),
                _levelLabel('Level 3 ', '(Umami)'),
              ],
            ),
          ),
        ),
        // Powder cards (right ~50%)
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: PowderCard(
                  kind: PowderKind.oobBlend,
                  powders: menu.oobBlendPowders,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PowderCard(
                  kind: PowderKind.tsuki,
                  powders: menu.tsukiPowders,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _levelLabel(String level, String qualifier) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: level,
            style: OobTypography.bodyBold.copyWith(fontSize: 18),
          ),
          TextSpan(
            text: qualifier,
            style: OobTypography.italic.copyWith(
              fontSize: 18,
              color: OobColors.oobNavy,
            ),
          ),
        ],
      ),
    );
  }
}
