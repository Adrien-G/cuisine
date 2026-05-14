import 'package:cuisine/controllers/cuisine_controller.dart';
import 'package:cuisine/models/ingredient.dart';
import 'package:cuisine/models/meal_history_entry.dart';
import 'package:cuisine/models/recipe.dart';
import 'package:cuisine/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reclasse uniquement les ingredients epicerie fiables', () async {
    final storage = _FakeStorageService();
    final controller = CuisineController(storageService: storage);

    controller.recipes.add(
      const Recipe(
        id: '1',
        name: 'Pancakes',
        ingredients: [
          Ingredient(name: 'lait', category: 'Frais'),
          Ingredient(name: 'oeufs', category: 'Frais'),
          Ingredient(name: 'beurre', category: 'Frais'),
        ],
        steps: 'Melanger.',
      ),
    );

    expect(controller.countSafeIngredientCategoryUpdates(), 2);

    final result = await controller.updateSafeIngredientCategories();

    expect(result.updatedIngredientsCount, 2);
    expect(result.updatedRecipesCount, 1);
    expect(controller.recipes.single.ingredients[0].category, 'Épicerie');
    expect(controller.recipes.single.ingredients[1].category, 'Épicerie');
    expect(controller.recipes.single.ingredients[2].category, 'Frais');
    expect(storage.saveCount, 1);
  });
}

class _FakeStorageService extends StorageService {
  int saveCount = 0;

  @override
  Future<void> saveData({
    required List<Recipe> recipes,
    required Map<String, String> weeklyPlanning,
    required Set<String> checkedShoppingItems,
    required List<String> pantryIngredientNames,
    required List<MealHistoryEntry> mealHistoryEntries,
  }) async {
    saveCount++;
  }
}
