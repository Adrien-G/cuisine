import 'package:cuisine/data/seasonal_ingredients.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ajoute les produits manquants aux mois attendus', () {
    expect(seasonalIngredientsByMonth[1], contains('kaki'));
    expect(seasonalIngredientsByMonth[4], contains('pamplemousse'));
    expect(seasonalIngredientsByMonth[7], contains('maïs'));
    expect(seasonalIngredientsByMonth[9], contains('noix'));
    expect(seasonalIngredientsByMonth[10], contains('échalote'));
  });

  test('reste conservateur sur les legumes du soleil en Alsace', () {
    expect(seasonalIngredientsByMonth[4], isNot(contains('tomate')));
    expect(seasonalIngredientsByMonth[4], isNot(contains('courgette')));
    expect(seasonalIngredientsByMonth[10], isNot(contains('tomate')));
  });

  test('ignore les fruits exotiques dans le score saison', () {
    expect(ingredientNameMatchesKnownProduce('banane'), isFalse);
    expect(ingredientNameMatchesKnownProduce('mangue'), isFalse);
    expect(ingredientNameMatchesKnownProduce('avocat'), isFalse);
  });
}
