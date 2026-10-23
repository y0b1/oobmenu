import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MenuLockSettings extends ChangeNotifier {
  MenuLockSettings(this.prefs);
  final SharedPreferences prefs;
  static late MenuLockSettings instance;
  String _hash(String code, String salt) =>
      sha256.convert(utf8.encode('$salt:$code')).toString();

  Future<void> changeCode(String code) async {
    if (!RegExp(r'^[0-9]{4}$').hasMatch(code)) {
      throw const FormatException('Enter exactly four digits.');
    }
    final salt = List.generate(
            24,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    if (!await prefs.setString('menu_unlock_code',
        jsonEncode({'salt': salt, 'hash': _hash(code, salt)}))) {
      throw StateError('Could not save the unlock code.');
    }
    await prefs.remove('menu_unlock_attempts');
    await prefs.remove('menu_unlock_until');
    notifyListeners();
  }

  Future<bool> unlock(String code) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((prefs.getInt('menu_unlock_until') ?? 0) > now) {
      throw const FormatException(
          'Too many attempts. Try again in five minutes.');
    }
    final saved = prefs.getString('menu_unlock_code');
    final record = saved == null ? null : jsonDecode(saved) as Map;
    final correct = record == null
        ? code == '1234'
        : _hash(code, record['salt'] as String) == record['hash'];
    if (!correct) {
      final attempts = (prefs.getInt('menu_unlock_attempts') ?? 0) + 1;
      await prefs.setInt('menu_unlock_attempts', attempts >= 5 ? 0 : attempts);
      if (attempts >= 5) await prefs.setInt('menu_unlock_until', now + 300000);
      return false;
    }
    await prefs.remove('menu_unlock_attempts');
    await prefs.remove('menu_unlock_until');
    return true;
  }
}
