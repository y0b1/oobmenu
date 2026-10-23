import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models.dart';
import '../data/menu_data.dart';

const _menuKey = 'menu_state';
const _passwordKey = 'admin_password';
const _defaultPassword = 'oob12345';

final adminPasswordProvider =
    NotifierProvider<AdminPasswordNotifier, String>(AdminPasswordNotifier.new);

class AdminPasswordNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return _defaultPassword;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_passwordKey);
    if (saved != null && saved != 'oob123') state = saved;
    if (saved == 'oob123') {
      await prefs.setString(_passwordKey, _defaultPassword);
    }
  }

  Future<bool> verify(String password) async {
    await _load();
    return state == password;
  }

  Future<void> update(String password) async {
    state = password;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey, password);
  }
}

class MenuState {
  const MenuState({
    required this.matchaSpecialtyDrinks,
    required this.hojichaSpecialtyDrinks,
    required this.coffeeWithMilk,
    required this.coffeeNoMilk,
    required this.coffeeSpecialtyDrinks,
    required this.addOns,
    required this.handpickedMatcha,
    required this.houjicha,
    required this.oobBlendPowders,
    required this.tsukiPowders,
  });

  final List<MenuItem> matchaSpecialtyDrinks;
  final List<MenuItem> hojichaSpecialtyDrinks;
  final List<MenuItem> coffeeWithMilk;
  final List<MenuItem> coffeeNoMilk;
  final List<MenuItem> coffeeSpecialtyDrinks;
  final List<AddOn> addOns;
  final MenuItem handpickedMatcha;
  final MenuItem houjicha;
  final List<PowderOption> oobBlendPowders;
  final List<PowderOption> tsukiPowders;

  List<MenuItem> get allItems => [
        handpickedMatcha,
        ...matchaSpecialtyDrinks,
        houjicha,
        ...hojichaSpecialtyDrinks,
        ...coffeeWithMilk,
        ...coffeeNoMilk,
        ...coffeeSpecialtyDrinks,
      ];

  MenuState copyWith({
    List<MenuItem>? matchaSpecialtyDrinks,
    List<MenuItem>? hojichaSpecialtyDrinks,
    List<MenuItem>? coffeeWithMilk,
    List<MenuItem>? coffeeNoMilk,
    List<MenuItem>? coffeeSpecialtyDrinks,
    List<AddOn>? addOns,
    MenuItem? handpickedMatcha,
    MenuItem? houjicha,
    List<PowderOption>? oobBlendPowders,
    List<PowderOption>? tsukiPowders,
  }) =>
      MenuState(
        matchaSpecialtyDrinks:
            matchaSpecialtyDrinks ?? this.matchaSpecialtyDrinks,
        hojichaSpecialtyDrinks:
            hojichaSpecialtyDrinks ?? this.hojichaSpecialtyDrinks,
        coffeeWithMilk: coffeeWithMilk ?? this.coffeeWithMilk,
        coffeeNoMilk: coffeeNoMilk ?? this.coffeeNoMilk,
        coffeeSpecialtyDrinks:
            coffeeSpecialtyDrinks ?? this.coffeeSpecialtyDrinks,
        addOns: addOns ?? this.addOns,
        handpickedMatcha: handpickedMatcha ?? this.handpickedMatcha,
        houjicha: houjicha ?? this.houjicha,
        oobBlendPowders: oobBlendPowders ?? this.oobBlendPowders,
        tsukiPowders: tsukiPowders ?? this.tsukiPowders,
      );

  Map<String, dynamic> toJson() => {
        'matchaSpecialtyDrinks':
            matchaSpecialtyDrinks.map((e) => e.toJson()).toList(),
        'hojichaSpecialtyDrinks':
            hojichaSpecialtyDrinks.map((e) => e.toJson()).toList(),
        'coffeeWithMilk': coffeeWithMilk.map((e) => e.toJson()).toList(),
        'coffeeNoMilk': coffeeNoMilk.map((e) => e.toJson()).toList(),
        'coffeeSpecialtyDrinks':
            coffeeSpecialtyDrinks.map((e) => e.toJson()).toList(),
        'addOns': addOns.map((e) => e.toJson()).toList(),
        'handpickedMatcha': handpickedMatcha.toJson(),
        'houjicha': houjicha.toJson(),
        'oobBlendPowders': oobBlendPowders.map((e) => e.toJson()).toList(),
        'tsukiPowders': tsukiPowders.map((e) => e.toJson()).toList(),
      };

  factory MenuState.fromJson(Map<String, dynamic> json) => MenuState(
        matchaSpecialtyDrinks: (json['matchaSpecialtyDrinks'] as List)
            .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        hojichaSpecialtyDrinks: (json['hojichaSpecialtyDrinks'] as List)
            .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        coffeeWithMilk: (json['coffeeWithMilk'] as List)
            .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        coffeeNoMilk: (json['coffeeNoMilk'] as List)
            .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        coffeeSpecialtyDrinks: (json['coffeeSpecialtyDrinks'] as List)
            .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        addOns: (json['addOns'] as List)
            .map((e) => AddOn.fromJson(e as Map<String, dynamic>))
            .toList(),
        handpickedMatcha:
            MenuItem.fromJson(json['handpickedMatcha'] as Map<String, dynamic>),
        houjicha: MenuItem.fromJson(json['houjicha'] as Map<String, dynamic>),
        oobBlendPowders: (json['oobBlendPowders'] as List)
            .map((e) => PowderOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        tsukiPowders: (json['tsukiPowders'] as List)
            .map((e) => PowderOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory MenuState.defaults() => MenuState(
        matchaSpecialtyDrinks: List.of(MenuData.matchaSpecialtyDrinks),
        hojichaSpecialtyDrinks: List.of(MenuData.hojichaSpecialtyDrinks),
        coffeeWithMilk: List.of(MenuData.coffeeWithMilk),
        coffeeNoMilk: List.of(MenuData.coffeeNoMilk),
        coffeeSpecialtyDrinks: List.of(MenuData.coffeeSpecialtyDrinks),
        addOns: List.of(MenuData.addOns),
        handpickedMatcha: MenuData.handpickedMatcha,
        houjicha: MenuData.houjicha,
        oobBlendPowders: List.of(MenuData.oobBlendPowders),
        tsukiPowders: List.of(MenuData.tsukiPowders),
      );
}

final menuStateProvider =
    NotifierProvider<MenuStateNotifier, MenuState>(MenuStateNotifier.new);

class MenuStateNotifier extends Notifier<MenuState> {
  @override
  MenuState build() {
    _load();
    return MenuState.defaults();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_menuKey);
    if (saved != null) {
      try {
        state = MenuState.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> update(MenuState newState) async {
    state = newState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_menuKey, jsonEncode(newState.toJson()));
  }

  Future<void> reset() async {
    state = MenuState.defaults();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_menuKey);
  }
}
