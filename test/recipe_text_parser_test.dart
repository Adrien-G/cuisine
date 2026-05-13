import 'package:cuisine/services/recipe_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeTextParser.guessCategory', () {
    test('classe le lait et les oeufs en epicerie', () {
      expect(RecipeTextParser.guessCategory('lait'), 'Épicerie');
      expect(RecipeTextParser.guessCategory('6 œufs'), 'Épicerie');
    });

    test('ne confond pas laitue et lait', () {
      expect(RecipeTextParser.guessCategory('laitue'), 'Fruits & légumes');
    });

    test('conserve les produits frais habituels en frais', () {
      expect(RecipeTextParser.guessCategory('beurre'), 'Frais');
      expect(RecipeTextParser.guessCategory('crème fraîche'), 'Frais');
    });
  });
}
