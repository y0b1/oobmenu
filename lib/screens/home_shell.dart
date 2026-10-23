import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/active_tab.dart';
import '../state/availability.dart';
import '../theme/oob_colors.dart';
import '../widgets/bottom_tab_bar.dart';
import '../widgets/cutoff_overlay.dart';
import 'matcha_screen.dart';
import '../ordering/order_screen.dart';
import '../ordering/order_client.dart';
import 'coffee_screen.dart';
import 'most_ordered_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeTabProvider);
    final availability = ref.watch(availabilityProvider);

    return Scaffold(
      backgroundColor: OobColors.oobCream,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: activeTab,
          children: [
            CutoffOverlay(
              active: availability.matcha.cutoff,
              label: 'Matcha',
              message: availability.matcha.cutoffMessage,
              child: const MatchaScreen(),
            ),
            CutoffOverlay(
              active: availability.coffee.cutoff,
              label: 'Coffee',
              message: availability.coffee.cutoffMessage,
              child: const CoffeeScreen(),
            ),
            const MostOrderedScreen(),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: OrderClient.instance,
        builder: (context, _) => FloatingActionButton.extended(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const OrderScreen())),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text('Order · ${OrderClient.instance.connection}'),
        ),
      ),
      bottomNavigationBar: const BottomTabBar(),
    );
  }
}
