enum WhiskMethod { coldWhisk, traditional }

enum PowderKind { oobBlend, tsuki }

enum PowderLevel { light, balanced, umami }

class PowderOption {
  const PowderOption({
    required this.kind,
    required this.level,
    required this.pricePhp,
  });

  final PowderKind kind;
  final PowderLevel level;
  final int pricePhp;

  PowderOption copyWith({int? pricePhp}) => PowderOption(
        kind: kind,
        level: level,
        pricePhp: pricePhp ?? this.pricePhp,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'level': level.name,
        'pricePhp': pricePhp,
      };

  factory PowderOption.fromJson(Map<String, dynamic> json) => PowderOption(
        kind: PowderKind.values.byName(json['kind'] as String),
        level: PowderLevel.values.byName(json['level'] as String),
        pricePhp: json['pricePhp'] as int,
      );
}

class MenuItem {
  const MenuItem({
    required this.name,
    this.descriptor,
    required this.pricePhp,
    required this.category,
    this.base,
  });

  final String name;
  final String? descriptor;
  final int pricePhp;
  final String category;
  final String? base;

  MenuItem copyWith({
    String? name,
    String? descriptor,
    int? pricePhp,
    String? category,
    String? base,
  }) =>
      MenuItem(
        name: name ?? this.name,
        descriptor: descriptor ?? this.descriptor,
        pricePhp: pricePhp ?? this.pricePhp,
        category: category ?? this.category,
        base: base ?? this.base,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'descriptor': descriptor,
        'pricePhp': pricePhp,
        'category': category,
        'base': base,
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        name: json['name'] as String,
        descriptor: json['descriptor'] as String?,
        pricePhp: json['pricePhp'] as int,
        category: json['category'] as String,
        base: json['base'] as String?,
      );
}

/// Visual accent used for a Most Ordered card. Matcha items render navy,
/// coffee items render orange.
enum DrinkAccent { matcha, coffee }

/// An entry on the Most Ordered tab. It is either a [reference] to an existing
/// menu item (kept in sync by name) or a fully [custom] drink whose details are
/// stored inline, independent of the rest of the menu.
class MostOrderedEntry {
  const MostOrderedEntry({
    this.refName,
    this.name,
    this.descriptor,
    this.pricePhp,
    this.accent,
  });

  /// Name of an existing [MenuItem]. Non-null for reference entries.
  final String? refName;

  /// Inline drink details. Non-null for custom entries.
  final String? name;
  final String? descriptor;
  final int? pricePhp;
  final DrinkAccent? accent;

  bool get isCustom => refName == null;

  /// A short label suitable for chips/pills in the admin panel.
  String get label => refName ?? name ?? '';

  factory MostOrderedEntry.reference(String name) =>
      MostOrderedEntry(refName: name);

  factory MostOrderedEntry.custom({
    required String name,
    String? descriptor,
    required int pricePhp,
    required DrinkAccent accent,
  }) =>
      MostOrderedEntry(
        name: name,
        descriptor: descriptor,
        pricePhp: pricePhp,
        accent: accent,
      );

  Map<String, dynamic> toJson() => {
        'refName': refName,
        'name': name,
        'descriptor': descriptor,
        'pricePhp': pricePhp,
        'accent': accent?.name,
      };

  factory MostOrderedEntry.fromJson(Map<String, dynamic> json) =>
      MostOrderedEntry(
        refName: json['refName'] as String?,
        name: json['name'] as String?,
        descriptor: json['descriptor'] as String?,
        pricePhp: json['pricePhp'] as int?,
        accent: json['accent'] != null
            ? DrinkAccent.values.byName(json['accent'] as String)
            : null,
      );
}

class AddOn {
  const AddOn({
    required this.name,
    required this.descriptor,
    required this.pricePhp,
  });

  final String name;
  final String descriptor;
  final int pricePhp;

  AddOn copyWith({
    String? name,
    String? descriptor,
    int? pricePhp,
  }) =>
      AddOn(
        name: name ?? this.name,
        descriptor: descriptor ?? this.descriptor,
        pricePhp: pricePhp ?? this.pricePhp,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'descriptor': descriptor,
        'pricePhp': pricePhp,
      };

  factory AddOn.fromJson(Map<String, dynamic> json) => AddOn(
        name: json['name'] as String,
        descriptor: json['descriptor'] as String,
        pricePhp: json['pricePhp'] as int,
      );
}
