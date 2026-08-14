import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oob_menu/screens/admin_panel.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Give the panel a tall viewport so its ListView lays out every section
  // (including the below-the-fold Most Ordered grid) instead of lazily
  // skipping it.
  Future<void> pumpTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AdminPanel()),
      ),
    );
    await tester.pump();
  }

  testWidgets('Most Ordered editor renders the six featured cards as a grid',
      (tester) async {
    await pumpTall(tester);

    // Six default entries -> six numbered mini cards, no more, no less.
    for (var n = 1; n <= 6; n++) {
      expect(find.text('#$n'), findsOneWidget, reason: 'card #$n should render');
    }
    expect(find.text('#7'), findsNothing);

    // Pumping the whole panel (fixed-height grid, mini cards) produced no
    // layout overflow or other render exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long-press dragging a card reorders without error',
      (tester) async {
    await pumpTall(tester);

    final firstCard = find.text('#1');
    final fourthCard = find.text('#4');
    expect(firstCard, findsOneWidget);
    expect(fourthCard, findsOneWidget);

    // Long-press card #1, drag it across to card #4's slot, then drop.
    final from = tester.getCenter(firstCard);
    final to = tester.getCenter(fourthCard);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 300)); // pass the hold delay
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Still exactly six cards, still no render/layout exception after the move.
    for (var n = 1; n <= 6; n++) {
      expect(find.text('#$n'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
