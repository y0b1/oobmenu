import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_spacing.dart';
import '../theme/oob_typography.dart';
import '../utils/peso.dart';

class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.item,
    this.showBase = false,
    this.nameColor,
    this.priceColor,
    this.unavailable = false,
  });

  final MenuItem item;
  final bool showBase;
  final Color? nameColor;
  final Color? priceColor;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final effectiveNameColor = nameColor ?? OobColors.oobNavy;
    final effectivePriceColor = priceColor ?? OobColors.oobNavy;

    return Opacity(
        opacity: unavailable ? 0.48 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: OobSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: item.name,
                            style: OobTypography.bodyBold.copyWith(
                              color: effectiveNameColor,
                            ),
                          ),
                          if (showBase && item.base != null) ...[
                            TextSpan(
                              text: ' | ',
                              style: OobTypography.body.copyWith(
                                color: OobColors.oobNavy,
                                fontSize: 17,
                              ),
                            ),
                            TextSpan(
                              text: item.base!,
                              style: OobTypography.body.copyWith(
                                color: OobColors.oobNavy,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (item.descriptor != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.descriptor!,
                        style: OobTypography.italic,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: OobSpacing.md),
              unavailable
                  ? Text(
                      'SOLD OUT',
                      style: OobTypography.bodyBold.copyWith(
                        color: OobColors.oobOrange,
                        fontSize: 13,
                        letterSpacing: 0.7,
                      ),
                    )
                  : Text(
                      formatPeso(item.pricePhp, withDecimals: true),
                      style: OobTypography.price.copyWith(
                        color: effectivePriceColor,
                      ),
                    ),
            ],
          ),
        ));
  }
}
