import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../state/whisking_method.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_spacing.dart';
import '../theme/oob_typography.dart';
import '../utils/haptics.dart';

class WhiskingToggle extends ConsumerStatefulWidget {
  const WhiskingToggle({super.key});

  @override
  ConsumerState<WhiskingToggle> createState() => _WhiskingToggleState();
}

class _WhiskingToggleState extends ConsumerState<WhiskingToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _whiskRotation;

  @override
  void initState() {
    super.initState();
    _whiskRotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _whiskRotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final method = ref.watch(whiskingMethodProvider);
    final isColdWhisk = method == WhiskMethod.coldWhisk;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: OobColors.oobCreamSoft,
            borderRadius: BorderRadius.circular(OobRadius.pill),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: isColdWhisk
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutQuart,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: OobColors.oobNavy,
                      borderRadius: BorderRadius.circular(OobRadius.pill),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!isColdWhisk) {
                          OobHaptics.light();
                          ref.read(whiskingMethodProvider.notifier).set(WhiskMethod.coldWhisk);
                          _whiskRotation.forward(from: 0);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isColdWhisk)
                            RotationTransition(
                              turns: Tween(begin: 0.0, end: 0.5)
                                  .animate(_whiskRotation),
                              child: const Icon(
                                Icons.blender,
                                size: 18,
                                color: OobColors.oobWhite,
                              ),
                            ),
                          if (isColdWhisk) const SizedBox(width: 6),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: OobTypography.body.copyWith(
                              color: isColdWhisk
                                  ? OobColors.oobWhite
                                  : OobColors.oobNavy,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            child: const Text('Cold Whisk'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (isColdWhisk) {
                          OobHaptics.light();
                          ref.read(whiskingMethodProvider.notifier).set(WhiskMethod.traditional);
                          _whiskRotation.forward(from: 0);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isColdWhisk)
                            RotationTransition(
                              turns: Tween(begin: 0.0, end: 0.5)
                                  .animate(_whiskRotation),
                              child: const Icon(
                                Icons.blender,
                                size: 18,
                                color: OobColors.oobWhite,
                              ),
                            ),
                          if (!isColdWhisk) const SizedBox(width: 6),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: OobTypography.body.copyWith(
                              color: !isColdWhisk
                                  ? OobColors.oobWhite
                                  : OobColors.oobNavy,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            child: const Text('Traditional'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
