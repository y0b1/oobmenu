import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oob_pos/main.dart';
import 'package:oob_pos/reports.dart';
import 'package:oob_pos/theme/transaction_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <Map<String, dynamic>>[];
  final sample = <String, dynamic>{
    'kind': 'daily',
    'start': '2026-09-11',
    'end': '2026-09-11',
    'day': '2026-09-11',
    'generatedAt': 1789128000000,
    'total': 12345,
    'count': 1,
    'cashSales': 12345,
    'otherSales': 0,
    'cancelledCount': 0,
    'previousGrandTotal': 0,
    'periodGrandTotal': 12345,
    'methods': [],
    'cashiers': [],
    'days': []
  };
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
      final args = jsonDecode(call.arguments as String) as Map<String, dynamic>;
      calls.add(args);
      if (call.method == 'cashier') {
        return jsonEncode({'id': 7, 'number': 'OOB-000007'});
      }
      if (args['operation'] == 'state') {
        return jsonEncode({
          'today': '2026-09-11',
          'profile': {},
          'reports': [],
          'lastClosedDay': '',
          'grandTotal': 12345,
          'audit': {'entries': 3}
        });
      }
      return jsonEncode({
        ...sample,
        'kind': args['kind'],
        if (args['operation'] == 'save') 'id': 1
      });
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(bridge, null));
  Widget host(Widget child) => MaterialApp(
      theme: transactionTheme(ThemeData(useMaterial3: true)), home: child);
  testWidgets('reports switch periods and save authoritative snapshots',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(const ReportsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('SALES REPORTS'), findsOneWidget);
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(calls.last['kind'], 'weekly');
    await tester.tap(find.text('Save summary'));
    await tester.pumpAndSettle();
    expect(
        calls.any((c) =>
            c['operation'] == 'save' &&
            c['kind'] == 'weekly' &&
            c['requestId'] != null),
        true);
    expect(find.text('WEEKLY #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('custom order submits centavos locally without catalog mutation',
      (tester) async {
    await tester.pumpWidget(host(Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () => customOrderDialog(context, {'id': 'shift-a'}),
                child: const Text('Custom order'))))));
    await tester.tap(find.text('Custom order'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Private drink');
    await tester.enterText(fields.at(1), '2');
    await tester.enterText(fields.at(2), '123.45');
    await tester.ensureVisible(find.text('Create order'));
    await tester.tap(find.text('Create order'));
    await tester.pumpAndSettle();
    expect(calls.single['operation'], 'customOrder');
    expect(calls.single['unitPrice'], 12345);
    expect(calls.single['quantity'], 2);
    expect(calls.single['shiftId'], 'shift-a');
    expect(tester.takeException(), isNull);
  });
}
