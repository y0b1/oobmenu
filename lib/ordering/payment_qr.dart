import 'package:flutter/material.dart';

/// Displays the untouched recipient block from the supplied image. The source
/// asset stays intact; only the surrounding festive artwork is clipped in UI.
class PaymentQrImage extends StatelessWidget {
  const PaymentQrImage({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'GCash QR, AR***L C., masked mobile number 092• ••••610',
        image: true,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 580,
            height: 776,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 1060,
                maxWidth: 1060,
                minHeight: 2046,
                maxHeight: 2046,
                child: Transform.translate(
                  offset: const Offset(-240, -376),
                  child: Image.asset('assets/images/oobqr.jpeg',
                      width: 1060,
                      height: 2046,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium),
                ),
              ),
            ),
          ),
        ),
      );
}
