import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/menu_data.dart';
import '../state/availability.dart';
import '../state/menu_state.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_spacing.dart';
import '../theme/oob_typography.dart';
import '../utils/peso.dart';
import '../widgets/pill_header.dart';
import '../widgets/powder_grid.dart';
import '../widgets/menu_row.dart';
import '../widgets/milk_notice.dart';
import '../widgets/footer_wordmark.dart';

class MatchaScreen extends ConsumerWidget {
  const MatchaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuStateProvider);
    final availability = ref.watch(availabilityProvider);
    final milk = availability.matcha.milk;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(
        left: OobSpacing.xl,
        right: OobSpacing.xl,
        top: OobSpacing.xxl,
        bottom: OobSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Milk availability notice (hidden when both milks are on hand)
          MilkNotice(milk: milk),

          // Section 1: Whisking Method (Variant A pill)
          Align(
            alignment: Alignment.centerLeft,
            child: PillHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WHISKING METHOD:',
                    style: OobTypography.displayCaps.copyWith(
                      color: OobColors.oobWhite,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Select your preferred method',
                    style: OobTypography.body.copyWith(
                      color: OobColors.oobWhite,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Whisking method rows (indented from pill left edge)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _whiskRow('Cold Whisk', MenuData.coldWhiskTraits),
                const SizedBox(height: 8),
                _whiskRow('Traditional', MenuData.traditionalTraits),
              ],
            ),
          ),

          const SizedBox(height: OobSpacing.lg),

          // Section 2: Matcha Latte title
          Text(
            'MATCHA LATTE:',
            style: OobTypography.displayCaps.copyWith(
              fontSize: 24,
              letterSpacing: 0.96,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Pick your powder',
            style: OobTypography.body.copyWith(fontSize: 18),
          ),

          const SizedBox(height: OobSpacing.md),

          // Section 3: Powder grid (level labels + cards)
          const PowderGrid(),

          const SizedBox(height: OobSpacing.sm),

          // Section 4: Footnote
          Text(
            'For single cultivars, ask your Barista...',
            style: OobTypography.italic.copyWith(fontSize: 16),
          ),

          const SizedBox(height: OobSpacing.lg),

          // Section 5: Handpicked Matcha (Variant B pill)
          Row(
            children: [
              Expanded(
                flex: 7,
                child: PillHeader(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'HANDPICKED MATCHA',
                              style: OobTypography.displayCaps.copyWith(
                                color: OobColors.oobWhite,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              menu.handpickedMatcha.descriptor!,
                              style: OobTypography.body.copyWith(
                                color: OobColors.oobWhite,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        availability.isDrinkCutoff(
                                menu.handpickedMatcha.category,
                                menu.handpickedMatcha.name)
                            ? 'SOLD OUT'
                            : formatPeso(
                                menu.handpickedMatcha.pricePhp,
                                withDecimals: true,
                              ),
                        style: OobTypography.price.copyWith(
                          color: OobColors.oobWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),

          const SizedBox(height: OobSpacing.lg),

          // Section 6: Specialty Drinks (matcha)
          Text(
            'SPECIALTY DRINKS',
            style: OobTypography.displayCaps.copyWith(
              fontSize: 16,
              letterSpacing: 0.64,
            ),
          ),
          const SizedBox(height: OobSpacing.sm),
          ...menu.matchaSpecialtyDrinks.map(
            (item) => MenuRow(
              item: item,
              unavailable: availability.isDrinkCutoff(item.category, item.name),
            ),
          ),

          const SizedBox(height: OobSpacing.lg),

          // Section 7: Houjicha Latte (Variant B pill)
          Row(
            children: [
              Expanded(
                flex: 7,
                child: PillHeader(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'HOUJICHA LATTE',
                              style: OobTypography.displayCaps.copyWith(
                                color: OobColors.oobWhite,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              menu.houjicha.descriptor!,
                              style: OobTypography.body.copyWith(
                                color: OobColors.oobWhite,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        availability.isDrinkCutoff(
                                menu.houjicha.category, menu.houjicha.name)
                            ? 'SOLD OUT'
                            : formatPeso(
                                menu.houjicha.pricePhp,
                                withDecimals: true,
                              ),
                        style: OobTypography.price.copyWith(
                          color: OobColors.oobWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),

          const SizedBox(height: OobSpacing.md),

          // Section 8: Specialty Drinks (houjicha)
          Text(
            'SPECIALTY DRINKS',
            style: OobTypography.displayCaps.copyWith(
              fontSize: 16,
              letterSpacing: 0.64,
            ),
          ),
          const SizedBox(height: OobSpacing.sm),
          ...menu.hojichaSpecialtyDrinks.map(
            (item) => MenuRow(
              item: item,
              unavailable: availability.isDrinkCutoff(item.category, item.name),
            ),
          ),

          const SizedBox(height: OobSpacing.xxl),

          // Section 9: Footer wordmark (full version with WHISK'RS)
          const FooterWordmark(),
        ],
      ),
    );
  }

  Widget _whiskRow(String name, List<String> traits) {
    return Row(
      children: [
        Text(
          name,
          style: OobTypography.bodyBold.copyWith(
            decoration: TextDecoration.underline,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '•',
          style: OobTypography.body.copyWith(fontSize: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            traits.join(' | '),
            style: OobTypography.body.copyWith(fontSize: 17),
          ),
        ),
      ],
    );
  }
}
