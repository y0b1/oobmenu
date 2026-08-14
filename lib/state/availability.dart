import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'availability_state';

/// Which milks are on hand for a given tab.
enum MilkAvailability { both, dairyOnly, oatOnly }

extension MilkAvailabilityLabel on MilkAvailability {
  String get label {
    switch (this) {
      case MilkAvailability.both:
        return 'Dairy & Oat';
      case MilkAvailability.dairyOnly:
        return 'Dairy only';
      case MilkAvailability.oatOnly:
        return 'Oat only';
    }
  }

  /// Short all-caps notice shown on the menu when milk is restricted.
  String? get notice {
    switch (this) {
      case MilkAvailability.both:
        return null;
      case MilkAvailability.dairyOnly:
        return 'DAIRY MILK ONLY';
      case MilkAvailability.oatOnly:
        return 'OAT MILK ONLY';
    }
  }
}

/// Operational availability for a single tab: whether it is cut off for the day
/// and which milks can be served.
class TabAvailability {
  const TabAvailability({
    this.cutoff = false,
    this.cutoffMessage = '',
    this.milk = MilkAvailability.both,
  });

  final bool cutoff;
  final String cutoffMessage;
  final MilkAvailability milk;

  TabAvailability copyWith({
    bool? cutoff,
    String? cutoffMessage,
    MilkAvailability? milk,
  }) =>
      TabAvailability(
        cutoff: cutoff ?? this.cutoff,
        cutoffMessage: cutoffMessage ?? this.cutoffMessage,
        milk: milk ?? this.milk,
      );

  Map<String, dynamic> toJson() => {
        'cutoff': cutoff,
        'cutoffMessage': cutoffMessage,
        'milk': milk.name,
      };

  factory TabAvailability.fromJson(Map<String, dynamic> json) =>
      TabAvailability(
        cutoff: json['cutoff'] as bool? ?? false,
        cutoffMessage: json['cutoffMessage'] as String? ?? '',
        milk: json['milk'] != null
            ? MilkAvailability.values.byName(json['milk'] as String)
            : MilkAvailability.both,
      );
}

class AvailabilityState {
  const AvailabilityState({
    this.matcha = const TabAvailability(),
    this.coffee = const TabAvailability(),
    this.cutoffDrinks = const <String>{},
  });

  final TabAvailability matcha;
  final TabAvailability coffee;

  /// Individual unavailable drinks, keyed as `category:name`.
  final Set<String> cutoffDrinks;

  static String drinkKey(String category, String name) => '$category:$name';

  bool isDrinkCutoff(String category, String name) =>
      cutoffDrinks.contains(drinkKey(category, name));

  AvailabilityState copyWith({
    TabAvailability? matcha,
    TabAvailability? coffee,
    Set<String>? cutoffDrinks,
  }) =>
      AvailabilityState(
        matcha: matcha ?? this.matcha,
        coffee: coffee ?? this.coffee,
        cutoffDrinks: cutoffDrinks ?? this.cutoffDrinks,
      );

  Map<String, dynamic> toJson() => {
        'matcha': matcha.toJson(),
        'coffee': coffee.toJson(),
        'cutoffDrinks': cutoffDrinks.toList(),
      };

  factory AvailabilityState.fromJson(Map<String, dynamic> json) =>
      AvailabilityState(
        matcha: json['matcha'] != null
            ? TabAvailability.fromJson(json['matcha'] as Map<String, dynamic>)
            : const TabAvailability(),
        coffee: json['coffee'] != null
            ? TabAvailability.fromJson(json['coffee'] as Map<String, dynamic>)
            : const TabAvailability(),
        cutoffDrinks: (json['cutoffDrinks'] as List<dynamic>?)
                ?.whereType<String>()
                .toSet() ??
            const <String>{},
      );
}

final availabilityProvider =
    NotifierProvider<AvailabilityNotifier, AvailabilityState>(
  AvailabilityNotifier.new,
);

class AvailabilityNotifier extends Notifier<AvailabilityState> {
  @override
  AvailabilityState build() {
    _load();
    return const AvailabilityState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        state = AvailabilityState.fromJson(
            jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> update(AvailabilityState newState) async {
    state = newState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(newState.toJson()));
  }
}
