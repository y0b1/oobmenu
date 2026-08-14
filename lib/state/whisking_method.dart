import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';

final whiskingMethodProvider = NotifierProvider<WhiskingMethodNotifier, WhiskMethod>(
  WhiskingMethodNotifier.new,
);

class WhiskingMethodNotifier extends Notifier<WhiskMethod> {
  @override
  WhiskMethod build() => WhiskMethod.coldWhisk;

  void toggle() {
    state = state == WhiskMethod.coldWhisk
        ? WhiskMethod.traditional
        : WhiskMethod.coldWhisk;
  }

  void set(WhiskMethod method) {
    state = method;
  }
}
