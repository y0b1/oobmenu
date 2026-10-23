import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../state/menu_state.dart';
import '../state/availability.dart';
import '../state/most_ordered.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_spacing.dart';
import '../theme/oob_typography.dart';
import '../utils/peso.dart';
import '../widgets/footer_wordmark.dart';
import 'admin_panel.dart';

class MostOrderedScreen extends ConsumerWidget {
  const MostOrderedScreen({super.key});

  void _promptPassword(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OobColors.oobCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Admin Access', style: OobTypography.bodyBold),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: OobTypography.body.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter password',
            hintStyle: OobTypography.body
                .copyWith(fontSize: 16, color: OobColors.oobMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: OobColors.oobMuted.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: OobColors.oobNavy),
            ),
          ),
          onSubmitted: (value) {
            Navigator.pop(ctx);
            _tryUnlock(context, ref, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: OobTypography.body
                    .copyWith(fontSize: 14, color: OobColors.oobMuted)),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text;
              Navigator.pop(ctx);
              _tryUnlock(context, ref, text);
            },
            child: Text('Unlock',
                style: OobTypography.bodyBold
                    .copyWith(fontSize: 14, color: OobColors.oobNavy)),
          ),
        ],
      ),
    );
  }

  Future<void> _tryUnlock(
      BuildContext context, WidgetRef ref, String input) async {
    final accepted =
        await ref.read(adminPasswordProvider.notifier).verify(input);
    if (!context.mounted) return;
    if (accepted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AdminPanel()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incorrect password',
              style: OobTypography.body
                  .copyWith(color: OobColors.oobWhite, fontSize: 14)),
          backgroundColor: OobColors.oobOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(mostOrderedProvider);
    final menu = ref.watch(menuStateProvider);
    final availability = ref.watch(availabilityProvider);
    final allItems = menu.allItems;

    // Resolve each entry: references pull live details from the menu (dropping
    // any whose item no longer exists), custom drinks carry their own details.
    final items = <_ResolvedDrink>[];
    for (final entry in entries) {
      if (entry.isCustom) {
        items.add(_ResolvedDrink(
          name: entry.name ?? '',
          descriptor: entry.descriptor,
          pricePhp: entry.pricePhp ?? 0,
          isMatcha: entry.accent == DrinkAccent.matcha,
        ));
      } else {
        MenuItem? match;
        for (final item in allItems) {
          if (item.name == entry.refName) {
            match = item;
            break;
          }
        }
        if (match == null) continue;
        if (availability.isDrinkCutoff(match.category, match.name)) continue;
        items.add(_ResolvedDrink(
          name: match.name,
          descriptor: match.descriptor,
          pricePhp: match.pricePhp,
          isMatcha: _isMatchaCategory(match.category),
        ));
      }
    }

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
          Row(
            children: [
              const Spacer(),
              Text(
                'MOST ORDERED',
                style: OobTypography.displayCaps.copyWith(
                  fontSize: 28,
                  letterSpacing: 1.12,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _promptPassword(context, ref),
                    child: Icon(
                      Icons.settings,
                      size: 22,
                      color: OobColors.oobMuted.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: OobSpacing.xl),
          for (int i = 0; i < items.length; i += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MostOrderedCard(item: items[i], index: i),
                ),
                const SizedBox(width: OobSpacing.md),
                if (i + 1 < items.length)
                  Expanded(
                    child: _MostOrderedCard(item: items[i + 1], index: i + 1),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
            if (i + 2 < items.length) const SizedBox(height: OobSpacing.md),
          ],
          const SizedBox(height: OobSpacing.xxl),
          const FooterWordmark(),
        ],
      ),
    );
  }
}

/// Resolved, display-ready drink for a Most Ordered card. Built from either a
/// live menu reference or a custom entry.
class _ResolvedDrink {
  const _ResolvedDrink({
    required this.name,
    required this.descriptor,
    required this.pricePhp,
    required this.isMatcha,
  });

  final String name;
  final String? descriptor;
  final int pricePhp;
  final bool isMatcha;
}

bool _isMatchaCategory(String category) =>
    category.contains('matcha') ||
    category.contains('houjicha') ||
    category == 'handpicked_matcha';

class _MostOrderedCard extends StatelessWidget {
  const _MostOrderedCard({
    required this.item,
    required this.index,
  });

  final _ResolvedDrink item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = item.isMatcha ? OobColors.oobNavy : OobColors.oobOrange;

    return Container(
      decoration: ShapeDecoration(
        color: color,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      padding: const EdgeInsets.all(OobSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${index + 1}',
            style: OobTypography.body.copyWith(
              color: OobColors.oobWhite.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: OobSpacing.md),
          Text(
            item.name,
            style: OobTypography.displayCaps.copyWith(
              color: OobColors.oobWhite,
              fontSize: 20,
              letterSpacing: 0.8,
            ),
          ),
          if (item.descriptor != null) ...[
            const SizedBox(height: OobSpacing.xs),
            Text(
              item.descriptor!,
              style: OobTypography.italic.copyWith(
                color: OobColors.oobWhite.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: OobSpacing.md),
          Text(
            formatPeso(item.pricePhp, withDecimals: true),
            style: OobTypography.price.copyWith(
              color: OobColors.oobWhite,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}
