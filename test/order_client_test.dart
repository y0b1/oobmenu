import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oob_menu/ordering/order_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimulatedPosClient extends OrderClient {
  bool offline = false, loseAcknowledgement = false;
  int submissions = 0;
  Map<String, dynamic>? accepted;
  final List<String> requestIds = [];
  @override
  Future<Map<String, dynamic>> api(String path,
      [Map<String, dynamic>? body]) async {
    if (offline) throw TimeoutException('POS unreachable');
    if (path == '/v1/catalog') return catalog;
    if (path.endsWith('/cancel')) {
      if (accepted!['state'] == 'paid') {
        throw OrderApiError(409, 'Already paid');
      }
      accepted!['state'] = 'cancelled';
      if (loseAcknowledgement) {
        loseAcknowledgement = false;
        throw TimeoutException('Cancellation saved, response lost');
      }
    }
    if (path == '/v1/orders') {
      submissions++;
      requestIds.add(body!['requestId'] as String);
      accepted ??= {
        'id': 1,
        'number': 'OOB-000001',
        'state': 'awaiting_payment',
        'total': 17000,
        'items': body['items'],
        'paymentChoice': body['paymentChoice']
      };
      if (loseAcknowledgement) {
        loseAcknowledgement = false;
        throw TimeoutException('Saved, response lost');
      }
    }
    return Map<String, dynamic>.from(accepted!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final line = {
    'id': 'spanish-latte',
    'name': 'Spanish Latte',
    'quantity': 1,
    'modifiers': <String>[],
    'notes': '',
    'expectedUnitPrice': 17000
  };
  Future<SimulatedPosClient> client() async {
    final client = SimulatedPosClient();
    await client.initialize(autoSync: false);
    client.credential = 'test-device';
    client.connection = 'Connected';
    await client.editCart([Map.of(line)]);
    return client;
  }

  test('lost cancellation acknowledgement synchronizes saved cancellation',
      () async {
    final c = await client();
    addTearDown(c.dispose);
    await c.submit();
    c.loseAcknowledgement = true;
    await c.cancelOrder();
    expect(c.order!['state'], 'awaiting_payment');
    expect(c.error, contains('Cancellation not confirmed'));
    await c.synchronize();
    expect(c.order!['state'], 'cancelled');
    expect(c.submissions, 1);
  });
  test(
      'offline cancellation is not queued and approval wins a cancellation race',
      () async {
    final c = await client();
    addTearDown(c.dispose);
    await c.submit();
    c.connection = 'Disconnected';
    await c.cancelOrder();
    expect(c.accepted!['state'], 'awaiting_payment');
    c.connection = 'Connected';
    c.accepted!['state'] = 'paid';
    await c.cancelOrder();
    expect(c.order!['state'], 'paid');
  });
  test('QR choice survives a lost acknowledgement and restart', () async {
    final first = await client();
    first.loseAcknowledgement = true;
    await first.submit(paymentChoice: 'qr');
    expect(first.pending!['paymentChoice'], 'qr');
    final accepted = first.accepted!;
    first.dispose();
    final restored = SimulatedPosClient()..accepted = accepted;
    addTearDown(restored.dispose);
    await restored.initialize(autoSync: false);
    expect(restored.pending!['paymentChoice'], 'qr');
    await restored.synchronize();
    expect(restored.order!['paymentChoice'], 'qr');
    expect(restored.order!['state'], 'awaiting_payment');
  });
  test('cash is sent explicitly and unknown payment choices are rejected',
      () async {
    final c = await client();
    addTearDown(c.dispose);
    await expectLater(c.submit(paymentChoice: 'invalid'), throwsArgumentError);
    expect(c.submissions, 0);
    await c.submit(paymentChoice: 'cash');
    expect(c.accepted!['paymentChoice'], 'cash');
  });
  test('double tap and lost acknowledgement keep the exact pending identity',
      () async {
    final c = await client();
    addTearDown(c.dispose);
    c.loseAcknowledgement = true;
    await Future.wait([c.submit(), c.submit()]);
    expect(c.submissions, 1);
    expect(c.order, isNull);
    expect(c.pending, isNotNull);
    final id = c.pending!['requestId'];
    final prefs = await SharedPreferences.getInstance();
    expect(
        (jsonDecode(prefs.getString('oob_order_session_v1')!) as Map)['pending']
            ['requestId'],
        id);
    await c.editCart([]);
    expect(c.cart.length, 1);
    await c.synchronize();
    expect(c.requestIds, [id, id]);
    expect(c.order!['number'], 'OOB-000001');
    expect(c.pending, isNull);
  });
  test(
      'restart restores frozen request and paid status after an offline approval',
      () async {
    final first = await client();
    first.loseAcknowledgement = true;
    await first.submit();
    final id = first.pending!['requestId'];
    final snapshot = first.accepted!;
    first.dispose();
    final restarted = SimulatedPosClient()
      ..accepted = {...snapshot, 'state': 'paid'};
    addTearDown(restarted.dispose);
    await restarted.initialize(autoSync: false);
    expect(restarted.pending!['requestId'], id);
    expect(restarted.cart.length, 1);
    await restarted.synchronize();
    expect(restarted.requestIds, [id]);
    expect(restarted.order!['state'], 'paid');
    await restarted.startNewOrder();
    expect(restarted.order, isNull);
    expect(restarted.cart, isEmpty);
    expect(restarted.accepted!['state'], 'paid');
  });
  test('ordinary offline cart never silently submits on reconnect', () async {
    final c = await client();
    addTearDown(c.dispose);
    c.offline = true;
    await c.synchronize();
    expect(c.connection, 'Reconnecting');
    await c.submit();
    expect(c.pending, isNull);
    await c.editCart([
      {...line, 'quantity': 2}
    ]);
    c.offline = false;
    await c.synchronize();
    expect(c.connection, 'Connected');
    expect(c.submissions, 0);
    expect(c.cart.single['quantity'], 2);
  });
  test(
      'accepted order synchronizes cancellation and approval after interruption',
      () async {
    final c = await client();
    addTearDown(c.dispose);
    await c.submit();
    c.offline = true;
    await c.synchronize();
    c.accepted!['state'] = 'paid';
    expect(c.order!['state'], 'awaiting_payment');
    c.offline = false;
    await c.synchronize();
    expect(c.order!['state'], 'paid');
    expect(c.submissions, 1);
  });
  test('certificate trust requires exact fingerprint and valid dates', () {
    final bytes = utf8.encode('certificate DER');
    final fingerprint = sha256.convert(bytes).toString();
    final start = DateTime(2026, 1, 1), end = DateTime(2027, 1, 1);
    expect(
        PosTransport.acceptsCertificate(
            bytes, fingerprint, start, end, DateTime(2026, 9, 1)),
        isTrue);
    expect(
        PosTransport.acceptsCertificate(utf8.encode('attacker'), fingerprint,
            start, end, DateTime(2026, 9, 1)),
        isFalse);
    expect(
        PosTransport.acceptsCertificate(
            bytes, fingerprint, start, end, DateTime(2028)),
        isFalse);
    expect(
        PosTransport.acceptsCertificate(
            bytes, fingerprint, start, end, DateTime(2025)),
        isFalse);
    expect(
        PosTransport.acceptsCertificate(
            bytes, '', start, end, DateTime(2026, 9, 1)),
        isFalse);
  });
  test('bundled catalog contains stable IDs and centavo prices', () async {
    final c = await client();
    addTearDown(c.dispose);
    expect(c.products.length, 26);
    expect(c.products.map((p) => p['id']).toSet().length, 26);
    expect(
        c.products.firstWhere((p) => p['id'] == 'handpicked-matcha')['price'],
        36000);
    expect(
        c.products.firstWhere((p) => p['id'] == 'powder-tsuki-umami')['price'],
        29000);
  });
}
