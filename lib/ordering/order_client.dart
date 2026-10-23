import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

String centavos(num value) => '₱\u2009${(value / 100).toStringAsFixed(2)}';
String newRequestId() => List.generate(32,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

class OrderApiError implements Exception {
  OrderApiError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class PosTransport {
  static String normalizePin(String value) =>
      value.replaceAll(RegExp(r'[\s:]'), '').toLowerCase();
  static bool acceptsCertificate(List<int> der, String pin, DateTime from,
          DateTime until, DateTime now) =>
      RegExp(r'^[a-f0-9]{64}$').hasMatch(pin) &&
      sha256.convert(der).toString() == pin &&
      !now.isBefore(from) &&
      !now.isAfter(until);
  static Future<Map<String, dynamic>> call(
      {required String host,
      required int port,
      required String pin,
      required String path,
      String credential = '',
      Map<String, dynamic>? body}) async {
    if (InternetAddress.tryParse(host)?.type != InternetAddressType.IPv4 ||
        port < 1 ||
        port > 65535 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(pin)) {
      throw OrderApiError(0,
          'Enter a valid IPv4 address, port, and complete 64-character fingerprint.');
    }
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = const Duration(seconds: 5);
    client.badCertificateCallback = (certificate, peerHost, peerPort) =>
        peerHost == host &&
        peerPort == port &&
        acceptsCertificate(certificate.der, pin, certificate.startValidity,
            certificate.endValidity, DateTime.now());
    try {
      final uri = Uri(scheme: 'https', host: host, port: port, path: path);
      final request = await client
          .openUrl(body == null ? 'GET' : 'POST', uri)
          .timeout(const Duration(seconds: 6));
      if (credential.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $credential');
      }
      request.headers.contentType = ContentType.json;
      final bytes = body == null ? <int>[] : utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final certificate = response.certificate;
      if (certificate == null ||
          !acceptsCertificate(certificate.der, pin, certificate.startValidity,
              certificate.endValidity, DateTime.now())) {
        throw OrderApiError(
            0, 'POS certificate does not match the paired fingerprint.');
      }
      final data = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        data.addAll(chunk);
        if (data.length > 1024 * 1024) {
          throw OrderApiError(0, 'POS response too large.');
        }
      }
      final json =
          Map<String, dynamic>.from(jsonDecode(utf8.decode(data)) as Map);
      if (response.statusCode != 200) {
        throw OrderApiError(response.statusCode,
            json['error'] as String? ?? 'POS rejected this request.');
      }
      return json;
    } finally {
      client.close(force: true);
    }
  }
}

class OrderClient extends ChangeNotifier {
  static final instance = OrderClient();
  Map<String, dynamic> catalog = {'products': [], 'modifiers': []};
  List<Map<String, dynamic>> cart = [];
  Map<String, dynamic>? pending, order;
  String host = '',
      pin = '',
      credential = '',
      connection = 'Disconnected',
      error = '';
  int port = 8443;
  bool busy = false, ready = false, _polling = false, _disposed = false;
  Timer? _timer;
  Completer<void>? _pollCompletion;
  SharedPreferences? _prefs;
  Future<void> _saveQueue = Future.value();
  bool get locked => pending != null || order != null;
  List<Map<String, dynamic>> get products => (catalog['products'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<Map<String, dynamic>> get modifiers => (catalog['modifiers'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Future<void> initialize({bool autoSync = true}) async {
    catalog = Map<String, dynamic>.from(
        jsonDecode(await rootBundle.loadString('assets/catalog.json')) as Map);
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs!.getString('oob_order_session_v1');
    if (saved != null) {
      final data = jsonDecode(saved) as Map;
      host = data['host'] as String;
      pin = data['pin'] as String;
      port = data['port'] as int;
      credential = data['credential'] as String;
      cart = (data['cart'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      pending = data['pending'] == null
          ? null
          : Map<String, dynamic>.from(data['pending'] as Map);
      order = data['order'] == null
          ? null
          : Map<String, dynamic>.from(data['order'] as Map);
      if (data['catalog'] != null) {
        catalog = Map<String, dynamic>.from(data['catalog'] as Map);
      }
    }
    ready = true;
    if (autoSync) {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => synchronize());
      unawaited(synchronize());
    }
    notifyListeners();
  }

  Future<void> save() {
    final text = jsonEncode({
      'host': host,
      'pin': pin,
      'port': port,
      'credential': credential,
      'cart': cart,
      'pending': pending,
      'order': order,
      'catalog': catalog
    });
    final operation = _saveQueue.catchError((Object _) {}).then((_) async {
      if (_prefs == null ||
          !await _prefs!.setString('oob_order_session_v1', text)) {
        throw StateError('Unable to save order state on this tablet.');
      }
    });
    _saveQueue = operation;
    return operation;
  }

  Future<Map<String, dynamic>> api(String path, [Map<String, dynamic>? body]) =>
      PosTransport.call(
          host: host,
          port: port,
          pin: pin,
          path: path,
          credential: credential,
          body: body);
  Future<void> configure(
      String address, int servicePort, String fingerprint, String code) async {
    if (!ready) {
      throw StateError('Local order storage is unavailable.');
    }
    if (busy) {
      throw StateError('Connection check in progress. Try again in a moment.');
    }
    final newPin = PosTransport.normalizePin(fingerprint);
    if (locked && (newPin != pin || code.trim().isNotEmpty)) {
      throw StateError(
          'Resolve the active order before pairing with a different identity. You can update the address with the same fingerprint and a blank code.');
    }
    busy = true;
    error = '';
    notifyListeners();
    try {
      await _pollCompletion?.future;
      var newCredential = credential;
      if (code.trim().isNotEmpty) {
        final pair = await PosTransport.call(
            host: address.trim(),
            port: servicePort,
            pin: newPin,
            path: '/v1/pair',
            body: {'code': code.trim()});
        newCredential = pair['credential'] as String;
        // Store credentials immediately: the one-time code has been consumed.
        host = address.trim();
        port = servicePort;
        pin = newPin;
        credential = newCredential;
        await save();
      }
      if (newCredential.isEmpty) {
        throw StateError('Enter the pairing code shown on the POS.');
      }
      final current = await PosTransport.call(
          host: address.trim(),
          port: servicePort,
          pin: newPin,
          path: '/v1/catalog',
          credential: newCredential);
      host = address.trim();
      port = servicePort;
      pin = newPin;
      credential = newCredential;
      catalog = current;
      await save();
      connection = 'Connected';
    } catch (e) {
      connection = 'Disconnected';
      error = 'Connection failed: $e';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> editCart(List<Map<String, dynamic>> next) async {
    if (locked || busy || !ready) return;
    busy = true;
    notifyListeners();
    final old = cart;
    try {
      cart = next;
      await save();
      error = '';
    } catch (e) {
      cart = old;
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> submit({String paymentChoice = 'cash'}) async {
    if (paymentChoice != 'cash' && paymentChoice != 'qr') {
      throw ArgumentError.value(paymentChoice, 'paymentChoice');
    }
    if (busy || locked || cart.isEmpty || connection != 'Connected') {
      return;
    }
    busy = true;
    error = '';
    notifyListeners();
    try {
      await _pollCompletion?.future;
      if (connection != 'Connected') return;
      pending = {
        'requestId': newRequestId(),
        'paymentChoice': paymentChoice,
        'items': jsonDecode(jsonEncode(cart))
      };
      await save(); // Never send before the durable retry identity exists.
      await _resolvePending();
    } catch (e) {
      connection = 'Reconnecting';
      error =
          'Submission not confirmed. Keep this order open; the same request will be checked again. $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _resolvePending() async {
    if (pending == null) return;
    // This also retries persistence after a disk-write failure before any network use.
    await save();
    try {
      final accepted = await api('/v1/orders', pending);
      order = accepted;
      pending = null;
      await save();
      error = '';
    } on OrderApiError catch (e) {
      if (e.status == 400 || e.status == 409) {
        pending = null;
        await save();
        error = '${e.message}. Review your cart before submitting.';
      } else {
        rethrow;
      }
    }
  }

  Future<void> synchronize() async {
    if (_polling || busy || credential.isEmpty || !ready || _disposed) return;
    _polling = true;
    _pollCompletion = Completer<void>();
    try {
      final current = await api('/v1/catalog');
      catalog = current;
      if (pending != null) await _resolvePending();
      if (order != null) {
        order = await api('/v1/orders/${order!['id']}');
        await save();
      }
      connection = 'Connected';
      if (error.startsWith('Connection lost:') ||
          error.startsWith('Submission not confirmed.')) {
        error = '';
      }
    } catch (e) {
      connection = e is OrderApiError && e.status == 401
          ? 'Disconnected'
          : 'Reconnecting';
      error = 'Connection lost: $e';
    } finally {
      _polling = false;
      _pollCompletion?.complete();
      _pollCompletion = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> cancelOrder() async {
    if (busy || order?['state'] != 'awaiting_payment') return;
    if (connection != 'Connected') {
      error =
          'Reconnect to the POS before cancelling. Your order is still active.';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await _pollCompletion?.future;
      if (order?['state'] != 'awaiting_payment') return;
      final id = order!['id'];
      try {
        order = await api('/v1/orders/$id/cancel', {});
        pending = null;
        error = '';
        await save();
      } on OrderApiError catch (e) {
        if (e.status == 409) {
          order = await api('/v1/orders/$id');
          await save();
        }
        rethrow;
      }
    } catch (e) {
      error =
          'Cancellation not confirmed: $e. Check the order status before trying again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> startNewOrder() async {
    if (busy ||
        order == null ||
        !['paid', 'cancelled'].contains(order!['state'])) {
      return;
    }
    busy = true;
    notifyListeners();
    final previousOrder = order;
    final previousCart = cart;
    try {
      await _pollCompletion?.future;
      cart = [];
      order = null;
      pending = null;
      error = '';
      await save();
    } catch (e) {
      order = previousOrder;
      cart = previousCart;
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
