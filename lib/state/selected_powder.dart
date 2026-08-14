import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';

class PowderSelection {
  const PowderSelection({this.kind, this.level});

  final PowderKind? kind;
  final PowderLevel? level;
}

final selectedPowderProvider = NotifierProvider<SelectedPowderNotifier, PowderSelection>(
  SelectedPowderNotifier.new,
);

class SelectedPowderNotifier extends Notifier<PowderSelection> {
  @override
  PowderSelection build() => const PowderSelection();

  void select(PowderKind kind, PowderLevel level) {
    state = PowderSelection(kind: kind, level: level);
  }

  void clear() {
    state = const PowderSelection();
  }
}
