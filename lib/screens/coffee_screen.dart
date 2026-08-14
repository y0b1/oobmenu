import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/availability.dart';
import '../state/menu_state.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_spacing.dart';
import '../theme/oob_typography.dart';
import '../utils/peso.dart';
import '../widgets/vertical_tag.dart';
import '../widgets/menu_row.dart';
import '../widgets/milk_notice.dart';
import '../widgets/footer_wordmark.dart';

class CoffeeScreen extends ConsumerWidget {
  const CoffeeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuStateProvider);
    final availability = ref.watch(availabilityProvider);
    final milk = availability.coffee.milk;

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

          // Section 1: OOB logo header (left-aligned)
          const _OobLogo(),

          const SizedBox(height: OobSpacing.lg),

          // Section 2: WITH MILK
          _TaggedSection(
            tag: const VerticalTag(
              text: 'WITH MILK',
              style: TagStyle.outlinedOrange,
            ),
            children: menu.coffeeWithMilk.map((item) {
              return MenuRow(
                item: item,
                showBase: true,
                priceColor: OobColors.oobOrange,
                unavailable:
                    availability.isDrinkCutoff(item.category, item.name),
              );
            }).toList(),
          ),

          const SizedBox(height: OobSpacing.lg),

          // Section 3: NO MILK
          _TaggedSection(
            tag: const VerticalTag(
              text: 'NO MILK',
              style: TagStyle.filledNavy,
            ),
            children: menu.coffeeNoMilk.map((item) {
              return MenuRow(
                item: item,
                showBase: true,
                nameColor: OobColors.oobOrange,
                unavailable:
                    availability.isDrinkCutoff(item.category, item.name),
              );
            }).toList(),
          ),

          const SizedBox(height: OobSpacing.lg),

          // Section 4: SPECIALTY DRINKS
          _TaggedSection(
            tag: const VerticalTag(
              text: 'SPECIALTY DRINKS',
              style: TagStyle.filledOrange,
            ),
            children: menu.coffeeSpecialtyDrinks.map((item) {
              final isSol = item.name == 'Sol';
              return MenuRow(
                item: item,
                nameColor: isSol ? OobColors.oobOrange : OobColors.oobNavy,
                priceColor: OobColors.oobOrange,
                unavailable:
                    availability.isDrinkCutoff(item.category, item.name),
              );
            }).toList(),
          ),

          const SizedBox(height: OobSpacing.lg),

          // Section 5: Add-ons pill (Variant C)
          Row(
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                  decoration: BoxDecoration(
                    color: OobColors.oobNavy,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      ...menu.addOns.asMap().entries.map((entry) {
                        final addon = entry.value;
                        final isLast = entry.key == menu.addOns.length - 1;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        addon.name,
                                        style: OobTypography.bodyBold.copyWith(
                                          color: OobColors.oobWhite,
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        addon.descriptor,
                                        style: OobTypography.body.copyWith(
                                          color: OobColors.oobWhite,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatPeso(addon.pricePhp,
                                      withDecimals: true),
                                  style: OobTypography.price.copyWith(
                                    color: OobColors.oobWhite,
                                  ),
                                ),
                              ],
                            ),
                            if (!isLast) const SizedBox(height: 16),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),

          const SizedBox(height: OobSpacing.xxl),

          // Section 6: Footer (coffee version, OUT OF BOREDOM only)
          const FooterWordmark(showWhiskrs: false),
        ],
      ),
    );
  }
}

class _OobLogo extends StatelessWidget {
  const _OobLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/oob_logo.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Text(
          'OOB',
          style: OobTypography.displayCaps.copyWith(
            color: OobColors.oobOrange,
            fontSize: 36,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}

class _TaggedSection extends StatelessWidget {
  const _TaggedSection({
    required this.tag,
    required this.children,
  });

  final VerticalTag tag;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: OobSpacing.lg),
          child: tag,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}
