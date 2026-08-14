import 'models.dart';

class MenuData {
  MenuData._();

  static const List<String> coldWhiskTraits = [
    'Less astringent',
    'Creamy',
    'Less Caffeine',
  ];

  static const List<String> traditionalTraits = [
    'Bodied',
    'Smooth',
    'More Caffeine',
  ];

  static const List<PowderOption> oobBlendPowders = [
    PowderOption(kind: PowderKind.oobBlend, level: PowderLevel.light, pricePhp: 210),
    PowderOption(kind: PowderKind.oobBlend, level: PowderLevel.balanced, pricePhp: 240),
    PowderOption(kind: PowderKind.oobBlend, level: PowderLevel.umami, pricePhp: 270),
  ];

  static const List<PowderOption> tsukiPowders = [
    PowderOption(kind: PowderKind.tsuki, level: PowderLevel.light, pricePhp: 230),
    PowderOption(kind: PowderKind.tsuki, level: PowderLevel.balanced, pricePhp: 260),
    PowderOption(kind: PowderKind.tsuki, level: PowderLevel.umami, pricePhp: 290),
  ];

  static const MenuItem handpickedMatcha = MenuItem(
    name: 'Handpicked Matcha',
    descriptor: 'A 200 year old craft preserved in modern day',
    pricePhp: 360,
    category: 'handpicked_matcha',
  );

  static const List<MenuItem> matchaSpecialtyDrinks = [
    MenuItem(
      name: 'Black Sesame Matcha',
      descriptor: 'Signature Black Sesame cream',
      pricePhp: 260,
      category: 'specialty_matcha',
    ),
    MenuItem(
      name: 'Himalayan Matcha',
      descriptor: 'Salted Cream',
      pricePhp: 260,
      category: 'specialty_matcha',
    ),
    MenuItem(
      name: 'Matcha-cho',
      descriptor: 'Matcha and Chocolate',
      pricePhp: 260,
      category: 'specialty_matcha',
    ),
    MenuItem(
      name: 'Strawberry Matcha',
      descriptor: 'Signature Strawberry jam',
      pricePhp: 290,
      category: 'specialty_matcha',
    ),
    MenuItem(
      name: 'Earl Grey Matcha',
      descriptor: 'Matcha and Earl Grey tea',
      pricePhp: 260,
      category: 'specialty_matcha',
    ),
  ];

  static const MenuItem houjicha = MenuItem(
    name: 'Houjicha Latte',
    descriptor: 'Roasted Matcha',
    pricePhp: 210,
    category: 'houjicha',
  );

  static const List<MenuItem> hojichaSpecialtyDrinks = [
    MenuItem(
      name: 'Dirty Houjicha',
      descriptor: 'Espresso and Roasted Matcha',
      pricePhp: 220,
      category: 'specialty_houjicha',
    ),
    MenuItem(
      name: 'Himalayan Houjicha',
      descriptor: 'Houjicha and Salted cream',
      pricePhp: 240,
      category: 'specialty_houjicha',
    ),
  ];

  static const List<MenuItem> coffeeWithMilk = [
    MenuItem(
      name: 'White',
      descriptor: 'Espresso and milk',
      pricePhp: 160,
      category: 'coffee_milk',
      base: 'milk-based',
    ),
    MenuItem(
      name: 'Spanish Latte',
      descriptor: 'Espresso and sweetened milk',
      pricePhp: 170,
      category: 'coffee_milk',
      base: 'milk-based',
    ),
    MenuItem(
      name: 'Mocha',
      descriptor: 'Espresso, chocolate, and milk',
      pricePhp: 180,
      category: 'coffee_milk',
      base: 'milk-based',
    ),
    MenuItem(
      name: 'Dirty Matcha',
      descriptor: 'Espresso, Matcha, and oat milk',
      pricePhp: 220,
      category: 'coffee_milk',
      base: 'milk-based',
    ),
  ];

  static const List<MenuItem> coffeeNoMilk = [
    MenuItem(
      name: 'Black',
      descriptor: 'Espresso and H₂O',
      pricePhp: 140,
      category: 'coffee_no_milk',
      base: 'water-based',
    ),
    MenuItem(
      name: 'Tonic Espresso',
      descriptor: 'Espresso and sparkling water',
      pricePhp: 170,
      category: 'coffee_no_milk',
      base: 'water-based',
    ),
  ];

  static const List<MenuItem> coffeeSpecialtyDrinks = [
    MenuItem(
      name: 'Eclipse',
      descriptor: 'Espresso and Mango',
      pricePhp: 190,
      category: 'specialty_coffee',
      base: 'soda-based',
    ),
    MenuItem(
      name: 'Newton',
      descriptor: 'Espresso and Apple',
      pricePhp: 190,
      category: 'specialty_coffee',
      base: 'soda-based',
    ),
    MenuItem(
      name: 'Black Sesame Latte',
      descriptor: 'Signature Black Sesame cream',
      pricePhp: 190,
      category: 'specialty_coffee',
      base: 'milk-based',
    ),
    MenuItem(
      name: 'Himalayan Latte',
      descriptor: 'Salted Cream',
      pricePhp: 190,
      category: 'specialty_coffee',
      base: 'milk-based',
    ),
    MenuItem(
      name: 'Sol',
      descriptor: 'Mango, Pomegranate, Lemon',
      pricePhp: 200,
      category: 'specialty_coffee',
      base: 'soda-based',
    ),
  ];

  static const List<AddOn> addOns = [
    AddOn(
      name: 'More caffeine!',
      descriptor: 'Extra shot',
      pricePhp: 50,
    ),
    AddOn(
      name: 'Make it big',
      descriptor: 'Up-size your cup',
      pricePhp: 50,
    ),
  ];

  static const List<String> mostOrderedNames = [
    'Handpicked Matcha',
    'Black Sesame Matcha',
    'Strawberry Matcha',
    'Spanish Latte',
    'Dirty Matcha',
    'Sol',
  ];

  static List<MenuItem> get mostOrderedItems {
    final all = [
      handpickedMatcha,
      ...matchaSpecialtyDrinks,
      ...coffeeWithMilk,
      ...coffeeSpecialtyDrinks,
    ];
    return mostOrderedNames
        .map((name) => all.firstWhere((item) => item.name == name))
        .toList();
  }

  static List<MenuItem> get allItems => [
    handpickedMatcha,
    ...matchaSpecialtyDrinks,
    houjicha,
    ...hojichaSpecialtyDrinks,
    ...coffeeWithMilk,
    ...coffeeNoMilk,
    ...coffeeSpecialtyDrinks,
  ];

  static String powderBackDescription(PowderKind kind) {
    switch (kind) {
      case PowderKind.oobBlend:
        return 'House blend. Three estates, one cup. Best with oat or whole milk.';
      case PowderKind.tsuki:
        return 'Single-region, ceremonial grade. Earthy, with a long finish.';
    }
  }
}
