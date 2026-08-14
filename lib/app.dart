import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/oob_theme.dart';
import 'screens/home_shell.dart';

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
      home: const HomeShell(),
    );
  }
}
