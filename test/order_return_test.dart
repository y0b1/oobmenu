import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oob_menu/ordering/order_client.dart';
import 'package:oob_menu/ordering/order_screen.dart';
import 'package:oob_menu/ordering/payment_qr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late OrderClient client;
  setUp(() async {
    client = OrderClient();
    SharedPreferences.setMockInitialValues({});
    await client.initialize(autoSync: false);
    client.order = {
      'id': 42,
      'number': 'OOB-000042',
      'state': 'paid',
      'total': 18000,
      'items': []
    };
    client.cart = [];
    client.pending = null;
    client.busy = false;
  });
  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => OrderScreen(client: client))),
                        child: const Text('General menu')))))));
    await tester.tap(find.text('General menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('paid confirmation returns to general menu after five seconds',
      (tester) async {
    await open(tester);
    expect(find.text('Payment confirmed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Payment confirmed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('General menu'), findsOneWidget);
    expect(find.byType(OrderScreen), findsNothing);
    expect(client.order, isNull);
    expect(client.pending, isNull);
    final saved = (await SharedPreferences.getInstance())
        .getString('oob_order_session_v1')!;
    expect(saved, contains('"order":null'));
  });
  testWidgets('Start new order returns to general menu immediately',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Start new order'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('General menu'), findsOneWidget);
    expect(client.order, isNull);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
  testWidgets('QR modal keeps supplied image visible until POS approval',
      (tester) async {
    client.order!['state'] = 'awaiting_payment';
    client.order!['paymentChoice'] = 'qr';
    client.connection = 'Connected';
    await open(tester);
    expect(find.byType(PaymentQrImage), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    expect(find.byType(StaffConnectionButton), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/oobqr.jpeg');
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(PaymentQrImage), findsOneWidget);
    client.order!['state'] = 'paid';
    client.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(PaymentQrImage), findsNothing);
    expect(find.text('Payment confirmed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('General menu'), findsOneWidget);
  });
  testWidgets('awaiting payment does not auto-dismiss', (tester) async {
    client.order!['state'] = 'awaiting_payment';
    await open(tester);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Awaiting payment'), findsOneWidget);
    expect(client.order, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
