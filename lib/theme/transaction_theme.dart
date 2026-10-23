import 'package:flutter/material.dart';
import 'oob_colors.dart';
import 'oob_typography.dart';
import '../widgets/pill_header.dart';

// Shared treatment for the new transactional screens; browse screens keep their theme.
ThemeData transactionTheme(ThemeData base) => base.copyWith(
      scaffoldBackgroundColor: OobColors.oobCream,
      colorScheme: base.colorScheme.copyWith(
          primary: OobColors.oobNavy,
          secondary: OobColors.oobOrange,
          surface: OobColors.oobCream,
          onSurface: OobColors.oobNavy,
          onPrimary: OobColors.oobWhite),
      textTheme: base.textTheme.copyWith(
          bodyLarge: OobTypography.body,
          bodyMedium: OobTypography.body.copyWith(fontSize: 16),
          bodySmall: OobTypography.italic.copyWith(fontSize: 14),
          titleLarge: OobTypography.displayCaps.copyWith(fontSize: 22),
          titleMedium: OobTypography.bodyBold,
          labelLarge: OobTypography.bodyBold.copyWith(fontSize: 16)),
      appBarTheme: AppBarTheme(
          backgroundColor: OobColors.oobCream,
          foregroundColor: OobColors.oobNavy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 96,
          titleTextStyle: OobTypography.displayCaps.copyWith(fontSize: 22)),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(64, 64),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              backgroundColor: OobColors.oobNavy,
              foregroundColor: OobColors.oobWhite,
              textStyle: OobTypography.bodyBold.copyWith(fontSize: 16),
              shape: const StadiumBorder(),
              elevation: 0)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 64),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              foregroundColor: OobColors.oobNavy,
              side: const BorderSide(color: OobColors.oobNavy),
              textStyle: OobTypography.bodyBold.copyWith(fontSize: 16),
              shape: const StadiumBorder())),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: OobColors.oobNavy,
              minimumSize: const Size(64, 56))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: OobColors.oobCreamSoft,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: OobColors.oobNavy, width: 2)),
          labelStyle: OobTypography.body.copyWith(fontSize: 16)),
      listTileTheme: ListTileThemeData(
          titleTextStyle: OobTypography.bodyBold,
          subtitleTextStyle: OobTypography.italic,
          leadingAndTrailingTextStyle: OobTypography.price,
          selectedTileColor: OobColors.oobCreamSoft,
          selectedColor: OobColors.oobNavy,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 8)),
      chipTheme: base.chipTheme.copyWith(
          shape: const StadiumBorder(),
          side: BorderSide.none,
          backgroundColor: OobColors.oobCreamSoft,
          selectedColor: OobColors.oobNavy,
          labelStyle: OobTypography.body.copyWith(fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      dialogTheme: DialogThemeData(
          backgroundColor: OobColors.oobCream,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titleTextStyle: OobTypography.displayCaps.copyWith(fontSize: 22),
          contentTextStyle: OobTypography.body.copyWith(fontSize: 18)),
      cardTheme: const CardThemeData(
          elevation: 0,
          color: OobColors.oobCreamSoft,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)))),
      dividerColor: OobColors.oobNavy.withValues(alpha: .15),
    );

class TransactionHeading extends StatelessWidget {
  const TransactionHeading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: PillHeader(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: OobTypography.displayCaps
                      .copyWith(color: OobColors.oobWhite)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!,
                    style: OobTypography.body
                        .copyWith(color: OobColors.oobWhite, fontSize: 15))
              ],
            ])),
      );
}
