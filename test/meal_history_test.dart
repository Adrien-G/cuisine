import 'package:cuisine/controllers/cuisine_controller.dart';
import 'package:cuisine/data/meal_slots.dart';
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

  test(
    'enregistre une recette realisee avec une date et un repas choisis',
    () async {
      final storage = _FakeStorageService();
      final controller = CuisineController(storageService: storage);

      const recipe = Recipe(
        id: 'soup',
        name: 'Soupe',
        emoji: 'S',
        ingredients: [Ingredient(name: 'carotte')],
        steps: 'Mixer.',
      );
      final cookedAt = DateTime(2026, 3, 25, 19);

      final firstResult = await controller.recordCookedRecipe(
        recipe: recipe,
        cookedAt: cookedAt,
        mealLabel: 'Soir',
      );
      final secondResult = await controller.recordCookedRecipe(
        recipe: recipe,
        cookedAt: cookedAt,
        mealLabel: 'Soir',
      );

      expect(firstResult.wasAdded, isTrue);
      expect(secondResult.wasAdded, isFalse);
      expect(firstResult.wasPlanningMealMarkedDone, isFalse);
      expect(secondResult.wasPlanningMealMarkedDone, isFalse);
      expect(controller.mealHistoryEntries.single.recipeName, 'Soupe');
      expect(controller.mealHistoryEntries.single.slotLabel, 'Soir');
      expect(controller.mealHistoryEntries.single.cookedAt, cookedAt);
      expect(storage.saveCount, 1);
    },
  );

  test(
    'marque le repas du planning comme realise quand la date correspond',
    () async {
      final storage = _FakeStorageService();
      final controller = CuisineController(storageService: storage);

      const recipe = Recipe(
        id: 'pasta',
        name: 'Pâtes',
        emoji: 'P',
        ingredients: [Ingredient(name: 'pâtes')],
        steps: 'Cuire.',
      );

      controller.recipes.add(recipe);
      controller.weeklyPlanning['lundi_soir'] = buildRecipePlanningValue(
        recipeId: recipe.id,
      );

      final cookedAt = controller.getCookedAtForSlot(
        mealSlots.firstWhere((slot) => slot.id == 'lundi_soir'),
        controller.getCurrentWeekStart(),
      );

      final result = await controller.recordCookedRecipe(
        recipe: recipe,
        cookedAt: cookedAt,
        mealLabel: 'Soir',
        sourcePlanningSlotId: 'lundi_soir',
      );

      expect(result.wasAdded, isTrue);
      expect(result.wasPlanningMealMarkedDone, isTrue);
      expect(
        getSpecialMealLabel(controller.weeklyPlanning['lundi_soir']!),
        completedMealLabel,
      );
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
