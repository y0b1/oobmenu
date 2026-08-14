import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'oob_colors.dart';

class OobTypography {
  OobTypography._();

  static TextStyle displayCaps = GoogleFonts.manrope(
    fontWeight: FontWeight.w800,
    fontSize: 18,
    letterSpacing: 0.72,
    color: OobColors.oobNavy,
  );

  static TextStyle bodyBold = GoogleFonts.mulish(
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: OobColors.oobNavy,
  );

  static TextStyle body = GoogleFonts.mulish(
    fontWeight: FontWeight.w400,
    fontSize: 20,
    color: OobColors.oobNavy,
  );

  static TextStyle italic = GoogleFonts.mulish(
    fontWeight: FontWeight.w400,
    fontSize: 18,
    fontStyle: FontStyle.italic,
    color: OobColors.oobMuted,
  );

  static TextStyle price = GoogleFonts.mulish(
    fontWeight: FontWeight.w400,
    fontSize: 20,
    color: OobColors.oobNavy,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  static TextStyle wordmark = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w400,
    fontSize: 20,
    letterSpacing: 1.6,
    color: OobColors.oobNavy,
  );

  static TextStyle wordmarkItalic = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w400,
    fontSize: 24,
    fontStyle: FontStyle.italic,
    letterSpacing: 1.44,
    color: OobColors.oobNavy,
  );
}
