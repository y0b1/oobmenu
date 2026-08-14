import 'package:flutter/material.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_typography.dart';

enum TagStyle { filledNavy, filledOrange, outlinedOrange }

class VerticalTag extends StatelessWidget {
  const VerticalTag({
    super.key,
    required this.text,
    this.style = TagStyle.filledNavy,
  });

  final String text;
  final TagStyle style;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final BoxBorder? border;

    switch (style) {
      case TagStyle.filledNavy:
        bgColor = OobColors.oobNavy;
        textColor = OobColors.oobWhite;
        border = null;
      case TagStyle.filledOrange:
        bgColor = OobColors.oobOrange;
        textColor = OobColors.oobWhite;
        border = null;
      case TagStyle.outlinedOrange:
        bgColor = Colors.transparent;
        textColor = OobColors.oobOrange;
        border = Border.all(color: OobColors.oobOrange, width: 2);
    }

    return RotatedBox(
      quarterTurns: -1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          border: border,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text.toUpperCase(),
          style: OobTypography.displayCaps.copyWith(
            fontSize: 14,
            letterSpacing: 1.4,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
