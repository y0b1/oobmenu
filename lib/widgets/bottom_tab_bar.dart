import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/active_tab.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_elevation.dart';
import '../theme/oob_typography.dart';
import '../utils/haptics.dart';

class BottomTabBar extends ConsumerWidget {
  const BottomTabBar({super.key});

  static const _tabs = ['Matcha', 'Coffee', 'Most Ordered'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeTabProvider);

    return Container(
      color: OobColors.oobCream,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_tabs.length, (i) {
              final isActive = i == activeTab;
              return GestureDetector(
                onTap: () {
                  if (!isActive) {
                    OobHaptics.light();
                    ref.read(activeTabProvider.notifier).setTab(i);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutQuart,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? OobColors.oobNavy : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isActive ? OobElevation.tabPill : null,
                  ),
                  child: Text(
                    _tabs[i],
                    style: OobTypography.body.copyWith(
                      color: isActive ? OobColors.oobWhite : OobColors.oobNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
