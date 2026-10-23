import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oob_menu/app.dart';
import 'package:oob_menu/state/menu_lock_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    MenuLockSettings.instance =
        MenuLockSettings(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      const ProviderScope(child: OobMenuApp()),
    );
    expect(find.text('Unlock menu'), findsOneWidget);
  });
}
