import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/menu_lock_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../ordering/order_screen.dart';
import '../theme/transaction_theme.dart';
import '../state/availability.dart';
import '../state/menu_state.dart';
import '../state/most_ordered.dart';
import '../theme/oob_colors.dart';
import '../theme/oob_spacing.dart';
import '../theme/oob_typography.dart';
import '../utils/haptics.dart';
import '../utils/peso.dart';

class AdminPanel extends ConsumerStatefulWidget {
  const AdminPanel({super.key});

  @override
  ConsumerState<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<AdminPanel> {
  late MenuState _menu;
  late List<MostOrderedEntry> _mostOrdered;
  late AvailabilityState _availability;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _menu = ref.read(menuStateProvider);
    _mostOrdered = List.of(ref.read(mostOrderedProvider));
    _availability = ref.read(availabilityProvider);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _save() async {
    await ref.read(menuStateProvider.notifier).update(_menu);
    await ref.read(mostOrderedProvider.notifier).update(_mostOrdered);
    await ref.read(availabilityProvider.notifier).update(_availability);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Menu saved',
              style: OobTypography.body
                  .copyWith(color: OobColors.oobWhite, fontSize: 14)),
          backgroundColor: OobColors.oobNavy,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OobColors.oobCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Menu', style: OobTypography.bodyBold),
        content: Text('Restore all items to defaults?',
            style: OobTypography.body.copyWith(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: OobTypography.body
                    .copyWith(fontSize: 14, color: OobColors.oobMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reset',
                style: OobTypography.bodyBold
                    .copyWith(fontSize: 14, color: OobColors.oobOrange)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final defaults = MenuState.defaults();
      final defaultOrdered = defaultMostOrdered();
      const defaultAvailability = AvailabilityState();
      await ref.read(menuStateProvider.notifier).reset();
      await ref.read(mostOrderedProvider.notifier).update(defaultOrdered);
      await ref.read(availabilityProvider.notifier).update(defaultAvailability);
      setState(() {
        _menu = defaults;
        _mostOrdered = List.of(defaultOrdered);
        _availability = defaultAvailability;
        _hasChanges = false;
      });
    }
  }

  Future<void> _changeUnlockCode() async {
    final code = TextEditingController();
    final confirmation = TextEditingController();
    var error = '';
    var saving = false;
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, update) => AlertDialog(
                title: const Text('Change menu unlock code'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final entry in {
                    code: 'New 4-digit code',
                    confirmation: 'Confirm code'
                  }.entries)
                    TextField(
                        controller: entry.key,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4)
                        ],
                        decoration: InputDecoration(labelText: entry.value)),
                  if (error.isNotEmpty) Text(error),
                ]),
                actions: [
                  TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (code.text != confirmation.text ||
                                  code.text.length != 4) {
                                update(() => error =
                                    'Enter the same four-digit code twice.');
                                return;
                              }
                              update(() => saving = true);
                              try {
                                await MenuLockSettings.instance
                                    .changeCode(code.text);
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) {
                                  update(() {
                                    error = '$e';
                                    saving = false;
                                  });
                                }
                              }
                            },
                      child: const Text('Save code')),
                ],
              ),
            ));
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();

    final newPw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OobColors.oobCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Password', style: OobTypography.bodyBold),
        content: TextField(
          controller: controller,
          obscureText: true,
          style: OobTypography.body.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'New password',
            hintStyle: OobTypography.body
                .copyWith(fontSize: 16, color: OobColors.oobMuted),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: OobColors.oobMuted.withValues(alpha: 0.3))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: OobColors.oobNavy)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: OobTypography.body
                    .copyWith(fontSize: 14, color: OobColors.oobMuted)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: Text('Save',
                style: OobTypography.bodyBold
                    .copyWith(fontSize: 14, color: OobColors.oobNavy)),
          ),
        ],
      ),
    );

    if (newPw != null && newPw.isNotEmpty) {
      await ref.read(adminPasswordProvider.notifier).update(newPw);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password updated',
                style: OobTypography.body
                    .copyWith(color: OobColors.oobWhite, fontSize: 14)),
            backgroundColor: OobColors.oobNavy,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OobColors.oobCream,
      appBar: AppBar(
        backgroundColor: OobColors.oobNavy,
        foregroundColor: OobColors.oobWhite,
        elevation: 0,
        title: Text(
          'ADMIN PANEL',
          style: OobTypography.displayCaps
              .copyWith(color: OobColors.oobWhite, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.pin_outlined, size: 20),
            tooltip: 'Change menu unlock code',
            onPressed: _changeUnlockCode,
          ),
          IconButton(
            icon: const Icon(Icons.wifi, size: 20),
            tooltip: 'POS connection',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => Theme(
                        data: transactionTheme(Theme.of(context)),
                        child: const MenuConnectionScreen()))),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline, size: 20),
            onPressed: _changePassword,
            tooltip: 'Change password',
          ),
          IconButton(
            icon: const Icon(Icons.restore, size: 20),
            onPressed: _confirmReset,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(OobSpacing.lg),
              children: [
                _buildAvailabilitySection(),
                const SizedBox(height: OobSpacing.lg),
                _buildMostOrderedSection(),
                const SizedBox(height: OobSpacing.lg),
                _buildPowderSection(
                    'OOB BLEND POWDERS', _menu.oobBlendPowders, true),
                const SizedBox(height: OobSpacing.lg),
                _buildPowderSection('TSUKI POWDERS', _menu.tsukiPowders, false),
                const SizedBox(height: OobSpacing.lg),
                _buildSingleItemSection(
                    'HANDPICKED MATCHA', _menu.handpickedMatcha, (item) {
                  setState(
                      () => _menu = _menu.copyWith(handpickedMatcha: item));
                  _markChanged();
                }),
                const SizedBox(height: OobSpacing.lg),
                _buildItemSection('MATCHA SPECIALTY',
                    _menu.matchaSpecialtyDrinks, 'specialty_matcha', (items) {
                  setState(() =>
                      _menu = _menu.copyWith(matchaSpecialtyDrinks: items));
                  _markChanged();
                }),
                const SizedBox(height: OobSpacing.lg),
                _buildSingleItemSection('HOUJICHA LATTE', _menu.houjicha,
                    (item) {
                  setState(() => _menu = _menu.copyWith(houjicha: item));
                  _markChanged();
                }),
                const SizedBox(height: OobSpacing.lg),
                _buildItemSection(
                    'HOUJICHA SPECIALTY',
                    _menu.hojichaSpecialtyDrinks,
                    'specialty_houjicha', (items) {
                  setState(() =>
                      _menu = _menu.copyWith(hojichaSpecialtyDrinks: items));
                  _markChanged();
                }),
                const SizedBox(height: OobSpacing.lg),
                _buildItemSection(
                    'COFFEE (WITH MILK)', _menu.coffeeWithMilk, 'coffee_milk',
                    (items) {
                  setState(() => _menu = _menu.copyWith(coffeeWithMilk: items));
                  _markChanged();
                }, defaultBase: 'milk-based'),
                const SizedBox(height: OobSpacing.lg),
                _buildItemSection(
                    'COFFEE (NO MILK)', _menu.coffeeNoMilk, 'coffee_no_milk',
                    (items) {
                  setState(() => _menu = _menu.copyWith(coffeeNoMilk: items));
                  _markChanged();
                }, defaultBase: 'water-based'),
                const SizedBox(height: OobSpacing.lg),
                _buildItemSection('COFFEE SPECIALTY',
                    _menu.coffeeSpecialtyDrinks, 'specialty_coffee', (items) {
                  setState(() =>
                      _menu = _menu.copyWith(coffeeSpecialtyDrinks: items));
                  _markChanged();
                }),
                const SizedBox(height: OobSpacing.lg),
                _buildAddOnSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onAdd}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: OobColors.oobNavy,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            title,
            style: OobTypography.displayCaps
                .copyWith(color: OobColors.oobWhite, fontSize: 12),
          ),
        ),
        const Spacer(),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: OobColors.oobOrange,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 14, color: OobColors.oobWhite),
                  const SizedBox(width: 4),
                  Text('Add',
                      style: OobTypography.body
                          .copyWith(color: OobColors.oobWhite, fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addCustomDrink() async {
    final entry = await showDialog<MostOrderedEntry>(
      context: context,
      builder: (ctx) => const _CustomDrinkDialog(),
    );
    if (entry != null && _mostOrdered.length < 6) {
      setState(() => _mostOrdered.add(entry));
      _markChanged();
    }
  }

  Future<void> _editCustomDrink(int index) async {
    final entry = await showDialog<MostOrderedEntry>(
      context: context,
      builder: (ctx) => _CustomDrinkDialog(initial: _mostOrdered[index]),
    );
    if (entry != null && index < _mostOrdered.length) {
      setState(() => _mostOrdered[index] = entry);
      _markChanged();
    }
  }

  Widget _buildMostOrderedSection() {
    final allItems = _menu.allItems;
    final atCapacity = _mostOrdered.length >= 6;

    // Build display-ready tiles keyed by their entry so the grid can track and
    // animate each card across reorders.
    final tiles = [
      for (final entry in _mostOrdered)
        _MoTile(ObjectKey(entry), _resolveEntry(entry)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('MOST ORDERED'),
        const SizedBox(height: OobSpacing.sm),
        Text(
          'This is your live layout. Hold a card and drag to rearrange it, '
          'like moving apps on a home screen. Tap the x to remove a card, or '
          'tap a custom card to edit it.',
          style: OobTypography.body
              .copyWith(fontSize: 13, color: OobColors.oobMuted),
        ),
        const SizedBox(height: OobSpacing.md),
        if (_mostOrdered.isEmpty)
          _emptyGridHint()
        else
          _MostOrderedGrid(
            tiles: tiles,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                final item = _mostOrdered.removeAt(oldIndex);
                _mostOrdered.insert(newIndex, item);
              });
              _markChanged();
            },
            onRemove: (index) {
              setState(() => _mostOrdered.removeAt(index));
              _markChanged();
            },
            onEditCustom: _editCustomDrink,
          ),
        const SizedBox(height: OobSpacing.md),
        GestureDetector(
          onTap: atCapacity ? null : _addCustomDrink,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: atCapacity
                    ? OobColors.oobMuted.withValues(alpha: 0.3)
                    : OobColors.oobOrange,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add,
                    size: 16,
                    color:
                        atCapacity ? OobColors.oobMuted : OobColors.oobOrange),
                const SizedBox(width: 6),
                Text(
                  'Add custom drink',
                  style: OobTypography.bodyBold.copyWith(
                    fontSize: 13,
                    color:
                        atCapacity ? OobColors.oobMuted : OobColors.oobOrange,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: OobSpacing.md),
        Row(
          children: [
            Text(
              'From the menu',
              style: OobTypography.body
                  .copyWith(fontSize: 12, color: OobColors.oobMuted),
            ),
            const Spacer(),
            Text(
              '${_mostOrdered.length}/6',
              style: OobTypography.bodyBold.copyWith(
                fontSize: 13,
                color: atCapacity ? OobColors.oobOrange : OobColors.oobMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allItems.map((item) {
            final selected =
                _mostOrdered.any((e) => !e.isCustom && e.refName == item.name);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _mostOrdered.removeWhere(
                        (e) => !e.isCustom && e.refName == item.name);
                  } else if (_mostOrdered.length < 6) {
                    _mostOrdered.add(MostOrderedEntry.reference(item.name));
                  }
                });
                _markChanged();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? OobColors.oobOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? OobColors.oobOrange
                        : OobColors.oobMuted.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  item.name,
                  style: OobTypography.body.copyWith(
                    color: selected ? OobColors.oobWhite : OobColors.oobNavy,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Resolves a Most Ordered entry into display-ready detail, mirroring the
  /// logic on [MostOrderedScreen]: references pull live menu detail, custom
  /// drinks carry their own, and a reference to a since-deleted item resolves
  /// as an invalid card the admin can remove.
  _ResolvedEditorDrink _resolveEntry(MostOrderedEntry entry) {
    if (entry.isCustom) {
      return _ResolvedEditorDrink(
        name: entry.name ?? '',
        pricePhp: entry.pricePhp ?? 0,
        isMatcha: entry.accent == DrinkAccent.matcha,
        isCustom: true,
        valid: true,
      );
    }
    for (final item in _menu.allItems) {
      if (item.name == entry.refName) {
        return _ResolvedEditorDrink(
          name: item.name,
          pricePhp: item.pricePhp,
          isMatcha: _isMatchaCategory(item.category),
          isCustom: false,
          valid: true,
        );
      }
    }
    return _ResolvedEditorDrink(
      name: entry.refName ?? '',
      pricePhp: 0,
      isMatcha: true,
      isCustom: false,
      valid: false,
    );
  }

  Widget _emptyGridHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OobColors.oobMuted.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        'No featured drinks yet. Tap items from the menu below to add them.',
        textAlign: TextAlign.center,
        style: OobTypography.body
            .copyWith(fontSize: 13, color: OobColors.oobMuted),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('AVAILABILITY'),
        const SizedBox(height: OobSpacing.sm),
        Text(
          'Cut off a tab for the day, or limit which milks are served.',
          style: OobTypography.body
              .copyWith(fontSize: 13, color: OobColors.oobMuted),
        ),
        const SizedBox(height: OobSpacing.sm),
        _availabilityCard(
          title: 'MATCHA',
          value: _availability.matcha,
          onChanged: (v) {
            setState(() => _availability = _availability.copyWith(matcha: v));
            _markChanged();
          },
        ),
        const SizedBox(height: OobSpacing.sm),
        _availabilityCard(
          title: 'COFFEE',
          value: _availability.coffee,
          onChanged: (v) {
            setState(() => _availability = _availability.copyWith(coffee: v));
            _markChanged();
          },
        ),
        const SizedBox(height: OobSpacing.sm),
        _drinkCutoffGroup(
          title: 'MATCHA DRINKS',
          categories: [
            ('HANDPICKED MATCHA', [_menu.handpickedMatcha]),
            ('MATCHA SPECIALTY', _menu.matchaSpecialtyDrinks),
            ('HOUJICHA LATTE', [_menu.houjicha]),
            ('HOUJICHA SPECIALTY', _menu.hojichaSpecialtyDrinks),
          ],
        ),
        const SizedBox(height: OobSpacing.sm),
        _drinkCutoffGroup(
          title: 'COFFEE DRINKS',
          categories: [
            ('WITH MILK', _menu.coffeeWithMilk),
            ('NO MILK', _menu.coffeeNoMilk),
            ('SPECIALTY', _menu.coffeeSpecialtyDrinks),
          ],
        ),
      ],
    );
  }

  Widget _drinkCutoffGroup({
    required String title,
    required List<(String, List<MenuItem>)> categories,
  }) {
    void setItems(List<MenuItem> items, bool cutoff) {
      final next = Set<String>.of(_availability.cutoffDrinks);
      for (final item in items) {
        final key = AvailabilityState.drinkKey(item.category, item.name);
        cutoff ? next.add(key) : next.remove(key);
      }
      setState(
          () => _availability = _availability.copyWith(cutoffDrinks: next));
      _markChanged();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OobColors.oobWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OobColors.oobMuted.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: OobTypography.displayCaps.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'Mark unavailable drinks as sold out on the menu',
            style: OobTypography.body.copyWith(
              fontSize: 12,
              color: OobColors.oobMuted,
            ),
          ),
          const SizedBox(height: 12),
          for (var categoryIndex = 0;
              categoryIndex < categories.length;
              categoryIndex++) ...[
            if (categoryIndex > 0)
              Divider(
                height: 24,
                color: OobColors.oobMuted.withValues(alpha: 0.15),
              ),
            Builder(builder: (context) {
              final category = categories[categoryIndex];
              final items = category.$2;
              final allSelected = items.isNotEmpty &&
                  items.every((item) =>
                      _availability.isDrinkCutoff(item.category, item.name));
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.$1,
                          style: OobTypography.bodyBold.copyWith(fontSize: 13),
                        ),
                      ),
                      Text(
                        'SELECT ALL',
                        style: OobTypography.bodyBold.copyWith(
                          fontSize: 11,
                          color: OobColors.oobMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ToggleSwitch(
                        value: allSelected,
                        onChanged: (on) => setItems(items, on),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: OobTypography.body.copyWith(fontSize: 14),
                            ),
                          ),
                          _ToggleSwitch(
                            value: _availability.isDrinkCutoff(
                              item.category,
                              item.name,
                            ),
                            onChanged: (on) => setItems([item], on),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _availabilityCard({
    required String title,
    required TabAvailability value,
    required void Function(TabAvailability) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OobColors.oobWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OobColors.oobMuted.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: OobTypography.displayCaps.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cut-off',
                        style: OobTypography.bodyBold.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      'Cover this tab with an unavailable overlay',
                      style: OobTypography.body
                          .copyWith(fontSize: 12, color: OobColors.oobMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ToggleSwitch(
                value: value.cutoff,
                onChanged: (on) => onChanged(value.copyWith(cutoff: on)),
              ),
            ],
          ),
          if (value.cutoff) ...[
            const SizedBox(height: 10),
            _InlineTextField(
              value: value.cutoffMessage,
              style: OobTypography.italic.copyWith(fontSize: 14),
              hintText: 'Overlay message (optional), e.g. "Back at 2 PM"',
              onChanged: (val) => onChanged(value.copyWith(cutoffMessage: val)),
            ),
          ],
          Divider(
              height: 28, color: OobColors.oobMuted.withValues(alpha: 0.15)),
          Text('Milk available',
              style: OobTypography.bodyBold.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          _MilkSelector(
            value: value.milk,
            onChanged: (m) => onChanged(value.copyWith(milk: m)),
          ),
        ],
      ),
    );
  }

  Widget _buildPowderSection(
      String title, List<PowderOption> powders, bool isOob) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        const SizedBox(height: OobSpacing.sm),
        ...powders.asMap().entries.map((entry) {
          final i = entry.key;
          final powder = entry.value;
          final levelName = powder.level.name[0].toUpperCase() +
              powder.level.name.substring(1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'Level ${i + 1} ($levelName)',
                    style: OobTypography.body.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: _PriceField(
                    value: powder.pricePhp,
                    onChanged: (val) {
                      final updated = List.of(powders);
                      updated[i] = powder.copyWith(pricePhp: val);
                      setState(() {
                        _menu = isOob
                            ? _menu.copyWith(oobBlendPowders: updated)
                            : _menu.copyWith(tsukiPowders: updated);
                      });
                      _markChanged();
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSingleItemSection(
      String title, MenuItem item, void Function(MenuItem) onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        const SizedBox(height: OobSpacing.sm),
        _ItemEditor(
          item: item,
          onUpdate: onUpdate,
        ),
      ],
    );
  }

  Widget _buildItemSection(
    String title,
    List<MenuItem> items,
    String category,
    void Function(List<MenuItem>) onUpdate, {
    String? defaultBase,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, onAdd: () {
          final updated = List.of(items);
          updated.add(MenuItem(
            name: 'New Item',
            descriptor: 'Description',
            pricePhp: 200,
            category: category,
            base: defaultBase,
          ));
          onUpdate(updated);
        }),
        const SizedBox(height: OobSpacing.sm),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ItemEditor(
              item: entry.value,
              onUpdate: (updated) {
                final list = List.of(items);
                list[i] = updated;
                onUpdate(list);
              },
              onDelete: items.length > 1
                  ? () {
                      final list = List.of(items);
                      list.removeAt(i);
                      onUpdate(list);
                    }
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAddOnSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('ADD-ONS', onAdd: () {
          final updated = List.of(_menu.addOns);
          updated.add(const AddOn(
              name: 'New Add-on', descriptor: 'Description', pricePhp: 50));
          setState(() => _menu = _menu.copyWith(addOns: updated));
          _markChanged();
        }),
        const SizedBox(height: OobSpacing.sm),
        ..._menu.addOns.asMap().entries.map((entry) {
          final i = entry.key;
          final addon = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AddOnEditor(
              addon: addon,
              onUpdate: (updated) {
                final list = List.of(_menu.addOns);
                list[i] = updated;
                setState(() => _menu = _menu.copyWith(addOns: list));
                _markChanged();
              },
              onDelete: _menu.addOns.length > 1
                  ? () {
                      final list = List.of(_menu.addOns);
                      list.removeAt(i);
                      setState(() => _menu = _menu.copyWith(addOns: list));
                      _markChanged();
                    }
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(OobSpacing.lg),
      decoration: BoxDecoration(
        color: OobColors.oobCream,
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, -2),
            color: OobColors.oobNavy.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _hasChanges ? _save : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _hasChanges
                  ? OobColors.oobNavy
                  : OobColors.oobMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              'SAVE CHANGES',
              style: OobTypography.displayCaps.copyWith(
                color: OobColors.oobWhite,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    required this.item,
    required this.onUpdate,
    this.onDelete,
  });

  final MenuItem item;
  final void Function(MenuItem) onUpdate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OobColors.oobWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OobColors.oobMuted.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InlineTextField(
                  value: item.name,
                  style: OobTypography.bodyBold.copyWith(fontSize: 16),
                  onChanged: (val) => onUpdate(item.copyWith(name: val)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: _PriceField(
                  value: item.pricePhp,
                  onChanged: (val) => onUpdate(item.copyWith(pricePhp: val)),
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.close,
                        size: 18,
                        color: OobColors.oobMuted.withValues(alpha: 0.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _InlineTextField(
            value: item.descriptor ?? '',
            style: OobTypography.italic.copyWith(fontSize: 14),
            hintText: 'Description (optional)',
            onChanged: (val) =>
                onUpdate(item.copyWith(descriptor: val.isEmpty ? null : val)),
          ),
        ],
      ),
    );
  }
}

class _AddOnEditor extends StatelessWidget {
  const _AddOnEditor({
    required this.addon,
    required this.onUpdate,
    this.onDelete,
  });

  final AddOn addon;
  final void Function(AddOn) onUpdate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OobColors.oobWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OobColors.oobMuted.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InlineTextField(
                  value: addon.name,
                  style: OobTypography.bodyBold.copyWith(fontSize: 16),
                  onChanged: (val) => onUpdate(addon.copyWith(name: val)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: _PriceField(
                  value: addon.pricePhp,
                  onChanged: (val) => onUpdate(addon.copyWith(pricePhp: val)),
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.close,
                        size: 18,
                        color: OobColors.oobMuted.withValues(alpha: 0.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _InlineTextField(
            value: addon.descriptor,
            style: OobTypography.italic.copyWith(fontSize: 14),
            onChanged: (val) => onUpdate(addon.copyWith(descriptor: val)),
          ),
        ],
      ),
    );
  }
}

class _InlineTextField extends StatefulWidget {
  const _InlineTextField({
    required this.value,
    required this.style,
    required this.onChanged,
    this.hintText,
  });

  final String value;
  final TextStyle style;
  final String? hintText;
  final void Function(String) onChanged;

  @override
  State<_InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<_InlineTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_InlineTextField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: widget.style,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: widget.hintText,
        hintStyle: widget.style
            .copyWith(color: OobColors.oobMuted.withValues(alpha: 0.4)),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _PriceField extends StatefulWidget {
  const _PriceField({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final void Function(int) onChanged;

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_PriceField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '₱ ',
          style: OobTypography.price
              .copyWith(fontSize: 14, color: OobColors.oobOrange),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            style: OobTypography.price.copyWith(fontSize: 16),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null && parsed > 0) widget.onChanged(parsed);
            },
          ),
        ),
      ],
    );
  }
}

/// A compact on-brand toggle used for the cut-off switches.
class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? OobColors.oobOrange
              : OobColors.oobMuted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: OobColors.oobWhite,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Three-way segmented selector for milk availability.
class _MilkSelector extends StatelessWidget {
  const _MilkSelector({
    required this.value,
    required this.onChanged,
  });

  final MilkAvailability value;
  final void Function(MilkAvailability) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: MilkAvailability.values.asMap().entries.map((entry) {
        final i = entry.key;
        final m = entry.value;
        final selected = m == value;
        final isLast = i == MilkAvailability.values.length - 1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(m),
            child: Container(
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? OobColors.oobNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? OobColors.oobNavy
                      : OobColors.oobMuted.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                m.label,
                textAlign: TextAlign.center,
                style: OobTypography.body.copyWith(
                  color: selected ? OobColors.oobWhite : OobColors.oobNavy,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Dialog for entering a fully custom Most Ordered drink. Pass [initial] to
/// pre-fill the fields and edit an existing drink instead of adding a new one.
class _CustomDrinkDialog extends StatefulWidget {
  const _CustomDrinkDialog({this.initial});

  final MostOrderedEntry? initial;

  @override
  State<_CustomDrinkDialog> createState() => _CustomDrinkDialogState();
}

class _CustomDrinkDialogState extends State<_CustomDrinkDialog> {
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptorController =
      TextEditingController(text: widget.initial?.descriptor ?? '');
  late final _priceController =
      TextEditingController(text: (widget.initial?.pricePhp ?? 200).toString());
  late DrinkAccent _accent = widget.initial?.accent ?? DrinkAccent.matcha;
  bool _showError = false;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptorController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text.trim());
    if (name.isEmpty || price == null || price <= 0) {
      setState(() => _showError = true);
      return;
    }
    final descriptor = _descriptorController.text.trim();
    Navigator.pop(
      context,
      MostOrderedEntry.custom(
        name: name,
        descriptor: descriptor.isEmpty ? null : descriptor,
        pricePhp: price,
        accent: _accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: OobColors.oobCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEditing ? 'Edit Drink' : 'Custom Drink',
          style: OobTypography.bodyBold),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_nameController, 'Name'),
            const SizedBox(height: 14),
            _field(_descriptorController, 'Description (optional)'),
            const SizedBox(height: 14),
            _field(_priceController, 'Price (whole pesos)', number: true),
            const SizedBox(height: 18),
            Text(
              'Card style',
              style: OobTypography.body
                  .copyWith(fontSize: 13, color: OobColors.oobMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: DrinkAccent.values.asMap().entries.map((entry) {
                final i = entry.key;
                final a = entry.value;
                final selected = a == _accent;
                final isLast = i == DrinkAccent.values.length - 1;
                final color = a == DrinkAccent.matcha
                    ? OobColors.oobNavy
                    : OobColors.oobOrange;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _accent = a),
                    child: Container(
                      margin: EdgeInsets.only(right: isLast ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? color : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        a == DrinkAccent.matcha
                            ? 'Matcha (navy)'
                            : 'Coffee (orange)',
                        textAlign: TextAlign.center,
                        style: OobTypography.body.copyWith(
                          fontSize: 12,
                          color: selected ? OobColors.oobWhite : color,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_showError) ...[
              const SizedBox(height: 12),
              Text(
                'Enter a name and a valid price.',
                style: OobTypography.body
                    .copyWith(fontSize: 13, color: OobColors.oobOrangeDeep),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: OobTypography.body
                  .copyWith(fontSize: 14, color: OobColors.oobMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add',
              style: OobTypography.bodyBold
                  .copyWith(fontSize: 14, color: OobColors.oobNavy)),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: OobTypography.body.copyWith(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: OobTypography.body
            .copyWith(fontSize: 16, color: OobColors.oobMuted),
        enabledBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(color: OobColors.oobMuted.withValues(alpha: 0.3)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: OobColors.oobNavy),
        ),
      ),
    );
  }
}

bool _isMatchaCategory(String category) =>
    category.contains('matcha') ||
    category.contains('houjicha') ||
    category == 'handpicked_matcha';

/// Display-ready detail for a Most Ordered card in the editor grid.
class _ResolvedEditorDrink {
  const _ResolvedEditorDrink({
    required this.name,
    required this.pricePhp,
    required this.isMatcha,
    required this.isCustom,
    required this.valid,
  });

  final String name;
  final int pricePhp;
  final bool isMatcha;
  final bool isCustom;

  /// False when this is a reference to a menu item that no longer exists.
  final bool valid;
}

/// A single grid card: a stable [key] (tied to its underlying entry so the grid
/// can animate it across reorders) paired with its resolved detail.
class _MoTile {
  const _MoTile(this.key, this.drink);

  final Key key;
  final _ResolvedEditorDrink drink;
}

/// A phone-home-screen style grid of the Most Ordered cards. It mirrors the
/// display layout in miniature: two columns of the same navy/orange cards.
/// Long-press a card to lift it, drag it around and the others flow out of the
/// way in real time, drop it to commit the new order. The delete badge removes
/// a card; tapping a custom card edits it.
class _MostOrderedGrid extends StatefulWidget {
  const _MostOrderedGrid({
    required this.tiles,
    required this.onReorder,
    required this.onRemove,
    required this.onEditCustom,
  });

  final List<_MoTile> tiles;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemove;
  final void Function(int index) onEditCustom;

  @override
  State<_MostOrderedGrid> createState() => _MostOrderedGridState();
}

class _MostOrderedGridState extends State<_MostOrderedGrid> {
  static const int _columns = 2;
  static const double _spacing = OobSpacing.md;
  static const double _cellHeight = 118;

  final GlobalKey _stackKey = GlobalKey();

  /// Working order used during a drag. Between drags it mirrors [widget.tiles];
  /// while dragging it is mutated locally so the cards animate into place, and
  /// the net move is committed to the parent on drop.
  late List<_MoTile> _order;

  /// Index in [_order] of the card currently being dragged, or null.
  int? _dragIndex;

  /// Index the drag started from, used to compute the committed move.
  int? _startIndex;

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.tiles);
  }

  @override
  void didUpdateWidget(_MostOrderedGrid old) {
    super.didUpdateWidget(old);
    // Resync from the parent whenever we are not mid-drag (adds, removes, edits,
    // and the committed reorder all arrive this way).
    if (_dragIndex == null) {
      _order = List.of(widget.tiles);
    }
  }

  double _cellWidth(double maxWidth) =>
      (maxWidth - _spacing * (_columns - 1)) / _columns;

  Offset _slotOffset(int index, double cellWidth) {
    final col = index % _columns;
    final row = index ~/ _columns;
    return Offset(
      col * (cellWidth + _spacing),
      row * (_cellHeight + _spacing),
    );
  }

  double _totalHeight(int count) {
    final rows = (count / _columns).ceil();
    if (rows == 0) return 0;
    return rows * _cellHeight + (rows - 1) * _spacing;
  }

  void _handleDragUpdate(Offset globalPosition, double cellWidth) {
    if (_dragIndex == null) return;
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final col =
        (local.dx / (cellWidth + _spacing)).floor().clamp(0, _columns - 1);
    final row = (local.dy / (_cellHeight + _spacing)).floor();
    final target = (row * _columns + col).clamp(0, _order.length - 1);
    if (target != _dragIndex) {
      setState(() {
        final tile = _order.removeAt(_dragIndex!);
        _order.insert(target, tile);
        _dragIndex = target;
      });
      OobHaptics.selection();
    }
  }

  void _endDrag() {
    final start = _startIndex;
    final end = _dragIndex;
    if (start != null && end != null && start != end) {
      widget.onReorder(start, end);
      OobHaptics.light();
    }
    setState(() {
      _dragIndex = null;
      _startIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = _cellWidth(constraints.maxWidth);
        return SizedBox(
          height: _totalHeight(_order.length),
          child: Stack(
            key: _stackKey,
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < _order.length; i++)
                AnimatedPositioned(
                  key: _order[i].key,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: _slotOffset(i, cellWidth).dx,
                  top: _slotOffset(i, cellWidth).dy,
                  width: cellWidth,
                  height: _cellHeight,
                  child: _buildDraggable(i, cellWidth),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggable(int index, double cellWidth) {
    final tile = _order[index];
    return LongPressDraggable<int>(
      data: index,
      delay: const Duration(milliseconds: 160),
      onDragStarted: () {
        setState(() {
          _startIndex = index;
          _dragIndex = index;
        });
        OobHaptics.medium();
      },
      onDragUpdate: (details) =>
          _handleDragUpdate(details.globalPosition, cellWidth),
      onDragEnd: (_) => _endDrag(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: cellWidth,
          height: _cellHeight,
          child: Transform.scale(
            scale: 1.05,
            child: _card(tile, index, elevated: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.28,
        child: _card(tile, index, interactive: false),
      ),
      child: _card(tile, index),
    );
  }

  Widget _card(
    _MoTile tile,
    int index, {
    bool elevated = false,
    bool interactive = true,
  }) {
    final d = tile.drink;
    final color = d.valid
        ? (d.isMatcha ? OobColors.oobNavy : OobColors.oobOrange)
        : OobColors.oobMuted;

    final card = Container(
      decoration: ShapeDecoration(
        color: color,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        shadows: [
          BoxShadow(
            blurRadius: elevated ? 26 : 10,
            offset: Offset(0, elevated ? 12 : 4),
            color: (elevated ? color : OobColors.oobNavy)
                .withValues(alpha: elevated ? 0.4 : 0.12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${index + 1}',
            style: OobTypography.body.copyWith(
              color: OobColors.oobWhite.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            d.name.isEmpty ? 'Untitled' : d.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OobTypography.displayCaps.copyWith(
              color: OobColors.oobWhite,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            d.valid ? formatPeso(d.pricePhp, withDecimals: true) : 'Removed',
            style: OobTypography.price.copyWith(
              color: OobColors.oobWhite,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );

    // Tapping a custom card reopens its editor; references are read-only.
    final body = (interactive && d.isCustom)
        ? GestureDetector(
            onTap: () => widget.onEditCustom(index),
            child: card,
          )
        : card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: body),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: interactive ? () => widget.onRemove(index) : null,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: OobColors.oobCream,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 6,
                    color: OobColors.oobNavy.withValues(alpha: 0.2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                size: 15,
                color: OobColors.oobNavy,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
