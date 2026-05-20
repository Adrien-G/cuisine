import 'package:cuisine/data/recipe_review_statuses.dart';
import 'package:cuisine/models/ingredient.dart';
import 'package:cuisine/models/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('utilise le statut importe par defaut pour les anciennes recettes', () {
    final recipe = Recipe.fromJson({
      'id': 'legacy',
      'name': 'Ancienne recette',
      'ingredients': ['farine'],
      'steps': 'Melanger.',
    });

    expect(recipe.reviewStatus, defaultRecipeReviewStatus);
  });

  test('sauvegarde et recharge le statut de verification', () {
    const recipe = Recipe(
      id: 'pasta',
      name: 'Pates',
      ingredients: [Ingredient(name: 'pates')],
      steps: 'Cuire.',
      reviewStatus: 'Validée',
    );

    final reloadedRecipe = Recipe.fromJson(recipe.toJson());

    expect(recipe.toJson()['reviewStatus'], 'Validée');
    expect(reloadedRecipe.reviewStatus, 'Validée');
  });

  test('sauvegarde et recharge une note globale sur 10', () {
    const recipe = Recipe(
      id: 'pasta',
      name: 'Pates',
      ingredients: [Ingredient(name: 'pates')],
      steps: 'Cuire.',
      rating: 8,
    );

    final reloadedRecipe = Recipe.fromJson(recipe.toJson());

    expect(recipe.toJson()['rating'], 8);
    expect(recipe.toJson().containsKey('difficulty'), isFalse);
    expect(reloadedRecipe.rating, 8);
    expect(reloadedRecipe.ratingText, '8/10');
  });

  test('ignore les notes hors limites au chargement', () {
    final recipe = Recipe.fromJson({
      'id': 'bad-rating',
      'name': 'Recette',
      'ingredients': ['farine'],
      'steps': 'Melanger.',
      'rating': 12,
    });

    expect(recipe.rating, isNull);
  });
}
