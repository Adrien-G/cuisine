const List<String> defaultPantryIngredientNames = [
  'sel',
  'poivre',
  'huile',
  'huile d’olive',
  'huile de tournesol',
  'vinaigre',
  'sucre',
  'farine',
  'levure',
  'épice',
  'épices',
  'paprika',
  'curry',
  'cumin',
  'cannelle',
  'muscade',
  'thym',
  'laurier',
  'origan',
  'herbes de provence',
];

bool shouldAutoExcludeFromShoppingList(String ingredientName) {
  final normalizedName = _normalizePantryText(ingredientName);

  return defaultPantryIngredientNames.any((pantryIngredient) {
    final normalizedPantryIngredient = _normalizePantryText(pantryIngredient);

    return normalizedName == normalizedPantryIngredient ||
        normalizedName.contains(normalizedPantryIngredient);
  });
}

String _normalizePantryText(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll('œ', 'oe')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r"[’']"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}