import 'package:flutter/material.dart';
import 'oob_colors.dart';

class OobTypography {
  OobTypography._();

  static const TextStyle displayCaps = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w800,
    fontSize: 18,
    letterSpacing: 0.72,
    color: OobColors.oobNavy,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: 'Mulish',
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: OobColors.oobNavy,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Mulish',
    fontWeight: FontWeight.w400,
    fontSize: 20,
    color: OobColors.oobNavy,
  );

  static const TextStyle italic = TextStyle(
    fontFamily: 'Mulish',
    fontWeight: FontWeight.w400,
    fontSize: 18,
    fontStyle: FontStyle.italic,
    color: OobColors.oobMuted,
  );

  static const TextStyle price = TextStyle(
    fontFamily: 'Mulish',
    fontWeight: FontWeight.w400,
    fontSize: 20,
    color: OobColors.oobNavy,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle wordmark = TextStyle(
    fontFamily: 'CormorantGaramond',
    fontWeight: FontWeight.w400,
    fontSize: 20,
    letterSpacing: 1.6,
    color: OobColors.oobNavy,
  );

  static const TextStyle wordmarkItalic = TextStyle(
    fontFamily: 'CormorantGaramond',
    fontWeight: FontWeight.w400,
    fontSize: 24,
    fontStyle: FontStyle.italic,
    letterSpacing: 1.44,
    color: OobColors.oobNavy,
  );
}
