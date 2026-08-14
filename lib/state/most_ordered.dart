import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models.dart';
import '../data/menu_data.dart';

const _key = 'most_ordered_v2';
const _legacyKey = 'most_ordered';

List<MostOrderedEntry> defaultMostOrdered() =>
    MenuData.mostOrderedNames.map(MostOrderedEntry.reference).toList();

final mostOrderedProvider =
    NotifierProvider<MostOrderedNotifier, List<MostOrderedEntry>>(
  MostOrderedNotifier.new,
);

class MostOrderedNotifier extends Notifier<List<MostOrderedEntry>> {
  @override
  List<MostOrderedEntry> build() {
    _load();
    return defaultMostOrdered();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        final list = (jsonDecode(saved) as List)
            .map((e) => MostOrderedEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        state = list;
        return;
      } catch (_) {}
    }
    // Migrate the legacy name-only list (stored as a plain string list).
    final legacy = prefs.getStringList(_legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      state = legacy.map(MostOrderedEntry.reference).toList();
    }
  }

  Future<void> update(List<MostOrderedEntry> entries) async {
    state = entries;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
