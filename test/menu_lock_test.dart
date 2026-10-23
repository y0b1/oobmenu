import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oob_menu/state/menu_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oob_menu/state/menu_lock_settings.dart';
import 'package:oob_menu/widgets/menu_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late MenuLockSettings settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = MenuLockSettings(await SharedPreferences.getInstance());
  });
  test('default code and owner-changed code persist across restart', () async {
    expect(await settings.unlock('1234'), true);
    await settings.changeCode('5678');
    final restored = MenuLockSettings(await SharedPreferences.getInstance());
    expect(await restored.unlock('1234'), false);
    expect(await restored.unlock('5678'), true);
    expect(
        (jsonDecode(settings.prefs.getString('menu_unlock_code')!) as Map).keys,
        unorderedEquals(['salt', 'hash']));
  });
  test(
      'owner password defaults correctly and saved changes apply on first verification',
      () async {
    final first = ProviderContainer();
    expect(await first.read(adminPasswordProvider.notifier).verify('oob12345'),
        true);
    await first
        .read(adminPasswordProvider.notifier)
        .update('new-owner-password');
    first.dispose();
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect(
        await restored.read(adminPasswordProvider.notifier).verify('oob12345'),
        false);
    expect(
        await restored
            .read(adminPasswordProvider.notifier)
            .verify('new-owner-password'),
        true);
  });
  test('five failed unlocks are rate limited across restart', () async {
    for (var i = 0; i < 5; i++) {
      expect(await settings.unlock('0000'), false);
    }
    final restored = MenuLockSettings(await SharedPreferences.getInstance());
    await expectLater(restored.unlock('1234'), throwsFormatException);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) =>
            MenuLock(settings: settings, child: child!),
        home: Scaffold(
            body: TextButton(
                onPressed: () {}, child: const Text('Browse drinks')))));
    await tester.pumpAndSettle();
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock menu'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('Unlock menu'), findsNothing);
  }

  testWidgets('cold start locks, activity resets five-minute idle timeout',
      (tester) async {
    await open(tester);
    expect(find.text('Unlock menu'), findsOneWidget);
    await unlock(tester);
    await tester.pump(const Duration(minutes: 4));
    await tester.tap(find.text('Browse drinks'));
    await tester.pump(const Duration(minutes: 4));
    expect(find.text('Unlock menu'), findsNothing);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Unlock menu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('sleep/background locks before resume without replacing menu',
      (tester) async {
    await open(tester);
    await unlock(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Unlock menu'), findsOneWidget);
    await unlock(tester);
    expect(find.text('Browse drinks'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
