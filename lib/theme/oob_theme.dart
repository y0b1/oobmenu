import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'oob_colors.dart';

class OobTheme {
  OobTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: OobColors.oobCream,
      colorScheme: const ColorScheme.light(
        primary: OobColors.oobNavy,
        secondary: OobColors.oobOrange,
        surface: OobColors.oobCream,
        onPrimary: OobColors.oobWhite,
        onSecondary: OobColors.oobWhite,
        onSurface: OobColors.oobNavy,
      ),
      textTheme: GoogleFonts.mulishTextTheme().apply(
        bodyColor: OobColors.oobNavy,
        displayColor: OobColors.oobNavy,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
