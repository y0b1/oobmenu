import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oob_pos/main.dart';
import 'package:oob_pos/operations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cash counts are parsed as integer centavos without rounding', () {
    expect(parseMoney('1500.50'), 150050);
    expect(parseMoney('0'), 0);
    expect(parseMoney('1.2'), 120);
    expect(parseMoney('1.001'), isNull);
    expect(parseMoney('-1'), isNull);
    expect(parseMoney('NaN'), isNull);
  });
  for (final choice in ['cash', 'qr']) {
    testWidgets('$choice kiosk choice automatically selects POS method',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => paymentDialog(context, {
                            'number': 'OOB-000001',
                            'total': 17000,
                            'paymentChoice': choice
                          }, {
                            'transactionOperator': {
                              'id': 'pos-local',
                              'cashier': 'POS operator'
                            },
                            'cashierTracking': false,
                            'methods': [
                              {
                                'id': 'cash',
                                'name': 'Cash',
                                'cash': true,
                                'enabled': true
                              },
                              {
                                'id': 'gcash',
                                'name': 'GCash',
                                'cash': false,
                                'enabled': true
                              },
                              {
                                'id': 'bpi',
                                'name': 'Monique BPI',
                                'cash': false,
                                'enabled': false
                              }
                            ]
                          }),
                      child: const Text('Pay'))))));
      await tester.tap(find.text('Pay'));
      await tester.pumpAndSettle();
      final field = tester.state<FormFieldState<String>>(
          find.byType(DropdownButtonFormField<String>));
      expect(field.value, choice == 'cash' ? 'cash' : 'gcash');
      expect(find.textContaining('Cashier:'), findsNothing);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
    });
  }
  for (final requirePin in [true, false]) {
    testWidgets(
        'review, verify, ${requirePin ? 'PIN' : 'owner-disabled PIN'} and beeper approval',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var approvals = 0;
      var reviews = 0;
      final order = <String, dynamic>{
        'id': 1,
        'number': 'OOB-000001',
        'state': 'awaiting_payment',
        'paymentChoice': 'qr',
        'total': 17000,
        'submittedAt': 1000,
        'items': <dynamic>[]
      };
      final operations = {
        'ownerConfigured': true,
        'requirePin': requirePin,
        'activeShift': {'id': 'shift-a', 'cashier': 'Alex'},
        'methods': [
          {'id': 'bpi', 'name': 'Monique BPI', 'cash': false, 'enabled': true}
        ]
      };
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(bridge,
          (call) async {
        if (call.method == 'status') {
          return jsonEncode({'running': true, 'connected': true});
        }
        if (call.method == 'history') return jsonEncode([order]);
        if (call.method == 'operations') return jsonEncode(operations);
        if (call.method == 'cashier') {
          final args = jsonDecode(call.arguments as String) as Map;
          if (args['operation'] == 'review') {
            reviews++;
            expect(args['confirmed'], true);
            order['reviewedAt'] = 1500;
            order['reviewedBy'] = 'Alex';
            order['reviewedShiftId'] = 'shift-a';
          }
          if (args['operation'] == 'approve') {
            approvals++;
            expect(reviews, 1);
            expect(args['id'], 1);
            expect(args['methodId'], 'bpi');
            expect(args['beeper'], '12');
            expect(args['verified'], true);
            expect(args['shiftId'], 'shift-a');
            expect(args['pin'], requirePin ? '1234' : '');
            order.addAll({
              'state': 'paid',
              'operator': 'Alex',
              'decisionAt': 2000,
              'beeper': '12',
              'fulfillment': 'queued',
              'queuedAt': 2000,
              'paymentMethod': {'name': 'Monique BPI', 'cash': false}
            });
          }
          return jsonEncode(order);
        }
        return null;
      });
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('OOB-000001'));
      await tester.pumpAndSettle();
      expect(find.text('2. Verify payment'), findsNothing);
      expect(find.text('Customer chose: QR'), findsOneWidget);
      expect(find.textContaining('Payment choice: QR'), findsOneWidget);
      await tester.tap(find.text('1. Recheck verbally with customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer confirmed the order'));
      await tester.pumpAndSettle();
      expect(reviews, 1);
      expect(approvals, 0);
      await tester.tap(find.text('2. Verify payment'));
      await tester.pumpAndSettle();
      expect(find.text('Monique BPI'), findsOneWidget);
      // The matching QR method is selected without another cashier selection.

      await tester.enterText(
          find.widgetWithText(TextField, 'Beeper number (1–9999)'), '12');
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(approvals, 0);
      expect(find.text('OOB-000001\n₱\u2009170.00'), findsOneWidget);
      if (requirePin) {
        await tester.enterText(
            find.widgetWithText(TextField, 'Cashier PIN (4 digits)'), '1234');
      } else {
        expect(find.widgetWithText(TextField, 'Cashier PIN (4 digits)'),
            findsNothing);
      }
      await tester.tap(find.text('Approve payment and queue'));
      await tester.pumpAndSettle();
      expect(approvals, 1);
      expect(find.textContaining('Paid by Alex'), findsOneWidget);
      expect(find.text('Queued'), findsNothing);
      expect(find.text("Don't show completed orders"), findsOneWidget);
      expect(find.text('OOB-000001 · Beeper 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('completed orders are hidden by default and can be shown',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(bridge,
        (call) async {
      if (call.method == 'status') return jsonEncode({'running': true});
      if (call.method == 'operations') {
        return jsonEncode({'cashierTracking': false});
      }
      if (call.method == 'history') {
        return jsonEncode([
          {
            'id': 1,
            'number': 'OOB-000001',
            'state': 'paid',
            'fulfillment': 'queued',
            'submittedAt': 1000,
            'total': 17000
          },
          {
            'id': 2,
            'number': 'OOB-000002',
            'state': 'paid',
            'fulfillment': 'completed',
            'submittedAt': 2000,
            'total': 18000
          },
          {
            'id': 3,
            'number': 'OOB-000003',
            'state': 'cancelled',
            'submittedAt': 3000,
            'total': 19000
          },
        ]);
      }
      return null;
    });
    await tester.pumpWidget(const PosApp());
    await tester.pumpAndSettle();
    expect(find.text('OOB-000001'), findsOneWidget);
    expect(find.text('OOB-000002'), findsNothing);
    expect(find.text('OOB-000003'), findsNothing);
    expect(find.byTooltip('Cashier shifts'), findsNothing);
    expect(find.textContaining('Active cashier:'), findsNothing);
    await tester.tap(find.text("Don't show completed orders"));
    await tester.pumpAndSettle();
    expect(find.text('OOB-000002'), findsOneWidget);
    expect(find.text('OOB-000003'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('native rejection keeps approval dialog open for correction',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(bridge,
        (call) async {
      throw PlatformException(
          code: 'POS', message: 'Incorrect password or PIN');
    });
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => operationDialog(context,
                    title: 'Check',
                    content: (_) => const Text('Inputs'),
                    submit: () => operate('approve', {})),
                child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect password or PIN'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
