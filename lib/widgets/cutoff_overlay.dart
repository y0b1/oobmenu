import 'package:flutter/material.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_typography.dart';

/// Wraps a tab's content and, when [active], drapes a frosted scrim with a
/// rotated "CUT-OFF" stamp over it. Used to mark the Matcha or Coffee menu as
/// unavailable for the day without removing its content.
class CutoffOverlay extends StatelessWidget {
  const CutoffOverlay({
    super.key,
    required this.active,
    required this.label,
    this.message = '',
    required this.child,
  });

  final bool active;

  /// Tab name shown on the stamp, e.g. "MATCHA".
  final String label;

  /// Optional line beneath the stamp. Falls back to a sensible default.
  final String message;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;

    final subtitle =
        message.trim().isEmpty ? 'Currently unavailable' : message.trim();

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: OobColors.oobCream.withValues(alpha: 0.86),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Transform.rotate(
                angle: -0.06,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: OobColors.oobNavy,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: OobColors.oobOrange,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        color: OobColors.oobNavy.withValues(alpha: 0.24),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: OobTypography.body.copyWith(
                          color: OobColors.oobOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'CUT-OFF',
                        style: OobTypography.displayCaps.copyWith(
                          color: OobColors.oobWhite,
                          fontSize: 40,
                          letterSpacing: 3.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: OobTypography.italic.copyWith(
                          color: OobColors.oobWhite.withValues(alpha: 0.85),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
