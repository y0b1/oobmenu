import 'dart:convert';
import 'dart:io';
import 'package:oob_menu/data/menu_data.dart';

void main() {
  String id(String name) => name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-$'), '');
  final products = [
    for (final item in MenuData.allItems)
      {
        'id': id(item.name),
        'name': item.name,
        'description': item.descriptor ?? '',
        'category': item.category,
        'price': item.pricePhp * 100,
        'modifiers': [
          if (item.category.contains('coffee')) ...['extra-shot', 'large'],
          if (item.category.contains('matcha')) ...['cold-whisk', 'traditional']
        ]
      },
    for (final p in [...MenuData.oobBlendPowders, ...MenuData.tsukiPowders])
      {
        'id': 'powder-${p.kind.name}-${p.level.name}',
        'name':
            '${p.kind.name == 'oobBlend' ? 'OOB' : 'Tsuki'} Level ${p.level.index + 1}',
        'description': 'Matcha Latte',
        'category': 'matcha_latte',
        'price': p.pricePhp * 100,
        'modifiers': ['cold-whisk', 'traditional']
      },
  ];
  final catalog = {
    'version': 2,
    'products': products,
    'modifiers': [
      {
        'id': 'extra-shot',
        'name': MenuData.addOns[0].name,
        'price': MenuData.addOns[0].pricePhp * 100
      },
      {
        'id': 'large',
        'name': MenuData.addOns[1].name,
        'price': MenuData.addOns[1].pricePhp * 100
      },
      {'id': 'cold-whisk', 'name': 'Cold Whisk', 'price': 0},
      {'id': 'traditional', 'name': 'Traditional', 'price': 0},
    ]
  };
  for (final path in [
    'assets/catalog.json',
    'oobpos/android/app/src/main/assets/catalog.json'
  ]) {
    File(path).parent.createSync(recursive: true);
    File(path).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(catalog)}\n');
  }
}
