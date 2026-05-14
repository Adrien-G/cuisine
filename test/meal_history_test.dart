import 'package:cuisine/controllers/cuisine_controller.dart';
import 'package:cuisine/data/planning_entries.dart';
import 'package:cuisine/models/ingredient.dart';
import 'package:cuisine/models/meal_history_entry.dart';
import 'package:cuisine/models/recipe.dart';
import 'package:cuisine/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'enregistre les recettes planifiees dans l historique sans doublon',
    () async {
      final storage = _FakeStorageService();
      final controller = CuisineController(storageService: storage);

      const pasta = Recipe(
        id: 'pasta',
        name: 'Pâtes',
        emoji: 'P',
        ingredients: [Ingredient(name: 'pâtes')],
        steps: 'Cuire.',
      );
      const sauce = Recipe(
        id: 'sauce',
        name: 'Sauce tomate',
        emoji: 'S',
        ingredients: [Ingredient(name: 'tomate')],
        steps: 'Mijoter.',
      );

      controller.recipes.addAll([pasta, sauce]);
      controller.weeklyPlanning['lundi_soir'] = buildRecipePlanningValue(
        recipeId: pasta.id,
        accompanimentRecipeId: sauce.id,
      );

      final firstResult = await controller.recordPlannedMealsAsCooked();
      final secondResult = await controller.recordPlannedMealsAsCooked();

      expect(firstResult.addedEntriesCount, 2);
      expect(secondResult.addedEntriesCount, 0);
      expect(controller.mealHistoryEntries, hasLength(2));
      expect(storage.saveCount, 1);
    },
  );
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
