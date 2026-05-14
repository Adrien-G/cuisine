import 'package:cuisine/data/pantry_ingredients.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detecte les ingredients du stock maison avec accents et pluriels', () {
    expect(
      shouldExcludeFromShoppingList(
        ingredientName: '2 c. à soupe d’huile d’olive',
        pantryIngredientNames: ['huile d’olive'],
      ),
      isTrue,
    );

    expect(
      shouldExcludeFromShoppingList(
        ingredientName: 'épices',
        pantryIngredientNames: ['épice'],
      ),
      isTrue,
    );
  });

  test('ne detecte pas un bout de mot comme stock maison', () {
    expect(
      shouldExcludeFromShoppingList(
        ingredientName: 'tournesol',
        pantryIngredientNames: ['sel'],
      ),
      isFalse,
    );
  });

  test('normalise et dedoublonne la liste du stock maison', () {
    expect(normalizePantryIngredientNames([' sel ', 'Sel', '', 'huile']), [
      'huile',
      'Sel',
    ]);
  });
}
