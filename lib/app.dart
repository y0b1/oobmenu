import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/oob_theme.dart';
import 'screens/home_shell.dart';
import 'widgets/menu_lock.dart';
import 'state/menu_lock_settings.dart';

class OobMenuApp extends StatelessWidget {
  const OobMenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF4F2EC),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'OOB Menu',
      debugShowCheckedModeBanner: false,
      theme: OobTheme.light,
      builder: (context, child) =>
          MenuLock(settings: MenuLockSettings.instance, child: child!),
      home: const HomeShell(),
    );
  }
}
