import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'state/menu_lock_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ordering/order_client.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  GoogleFonts.config.allowRuntimeFetching = false;
  MenuLockSettings.instance =
      MenuLockSettings(await SharedPreferences.getInstance());
  try {
    await OrderClient.instance.initialize();
  } catch (error) {
    OrderClient.instance.error =
        'Could not restore local order data. Checkout is disabled. Ask staff to check this tablet: $error';
  }

  runApp(
    const ProviderScope(
      child: OobMenuApp(),
    ),
  );
}
