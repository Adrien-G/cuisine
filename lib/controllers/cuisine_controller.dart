import 'dart:math';

import '../data/meal_slots.dart';
import '../data/planning_entries.dart';
import '../models/recipe.dart';
import '../services/seasonality_service.dart';
import '../services/storage_service.dart';

enum SelectAccompanimentResult { added, missingMainRecipe, fullDish }

class FillPlanningResult {
  const FillPlanningResult({
    required this.addedMealsCount,
    required this.hasRecipes,
  });

  final int addedMealsCount;
  final bool hasRecipes;

  bool get isPlanningAlreadyFull => hasRecipes && addedMealsCount == 0;
}

class CuisineController {
  CuisineController({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  final StorageService _storageService;

  bool isLoading = true;

  final List<Recipe> recipes = [];
  final Map<String, String> weeklyPlanning = {};
  final Set<String> checkedShoppingItems = {};

  AppData get appData {
    return AppData(
      recipes: List<Recipe>.from(recipes),
      weeklyPlanning: Map<String, String>.from(weeklyPlanning),
      checkedShoppingItems: Set<String>.from(checkedShoppingItems),
    );
  }

  Future<void> loadData() async {
    final appData = await _storageService.loadData();

    final migratedPlanning = migrateLegacyPlanning(appData.weeklyPlanning);
    final hasLegacyPlanning = containsLegacyPlanningKeys(
      appData.weeklyPlanning,
    );

    recipes
      ..clear()
      ..addAll(appData.recipes);

    weeklyPlanning
      ..clear()
      ..addAll(migratedPlanning);

    checkedShoppingItems
      ..clear()
      ..addAll(appData.checkedShoppingItems);

    isLoading = false;

    if (hasLegacyPlanning) {
      await saveData();
    }
  }

  Future<void> saveData() {
    return _storageService.saveData(
      recipes: recipes,
      weeklyPlanning: weeklyPlanning,
      checkedShoppingItems: checkedShoppingItems,
    );
  }

  Future<void> restoreDataFromBackup(AppData importedData) async {
    recipes
      ..clear()
      ..addAll(importedData.recipes);

    weeklyPlanning
      ..clear()
      ..addAll(importedData.weeklyPlanning);

    checkedShoppingItems
      ..clear()
      ..addAll(importedData.checkedShoppingItems);

    await saveData();
  }

  Future<void> addRecipe(Recipe newRecipe) async {
    recipes.add(newRecipe);
    await saveData();
  }

  Future<Recipe?> toggleFavoriteRecipe(Recipe recipe) async {
    final recipeIndex = recipes.indexWhere((item) => item.id == recipe.id);

    if (recipeIndex == -1) {
      return null;
    }

    final updatedRecipe = recipes[recipeIndex].copyWith(
      isFavorite: !recipes[recipeIndex].isFavorite,
    );

    recipes[recipeIndex] = updatedRecipe;

    await saveData();

    return updatedRecipe;
  }

  Future<void> updateRecipe(Recipe updatedRecipe) async {
    final index = recipes.indexWhere((recipe) => recipe.id == updatedRecipe.id);

    if (index != -1) {
      recipes[index] = updatedRecipe;
    }

    checkedShoppingItems.clear();

    await saveData();
  }

  Future<void> deleteRecipe(Recipe recipeToDelete) async {
    recipes.removeWhere((recipe) => recipe.id == recipeToDelete.id);

    weeklyPlanning.removeWhere((slotId, planningValue) {
      return getRecipeIdsFromPlanningValue(
        planningValue,
      ).contains(recipeToDelete.id);
    });

    checkedShoppingItems.clear();

    await saveData();
  }

  Future<String> setSpecialMealForSlot(String slotId, String label) async {
    final specialMealLabel = label.trim().isEmpty
        ? defaultSpecialMealLabel
        : label.trim();

    weeklyPlanning[slotId] = buildSpecialMealValue(specialMealLabel);
    checkedShoppingItems.clear();

    await saveData();

    return specialMealLabel;
  }

  Recipe? getRecipeById(String recipeId) {
    for (final recipe in recipes) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }

    return null;
  }

  Future<SelectAccompanimentResult> selectAccompanimentForSlot(
    String slotId,
    Recipe accompanimentRecipe,
  ) async {
    final currentValue = weeklyPlanning[slotId];
    final mainRecipeId = getMainRecipeIdFromPlanningValue(currentValue);

    if (mainRecipeId == null) {
      return SelectAccompanimentResult.missingMainRecipe;
    }

    final mainRecipe = getRecipeById(mainRecipeId);

    if (mainRecipe == null) {
      return SelectAccompanimentResult.missingMainRecipe;
    }

    if (mainRecipe.tags.contains('Plat complet')) {
      return SelectAccompanimentResult.fullDish;
    }

    weeklyPlanning[slotId] = buildRecipePlanningValue(
      recipeId: mainRecipeId,
      accompanimentRecipeId: accompanimentRecipe.id,
    );
    checkedShoppingItems.clear();

    await saveData();

    return SelectAccompanimentResult.added;
  }

  Future<void> removeAccompanimentFromSlot(String slotId) async {
    final currentValue = weeklyPlanning[slotId];

    if (currentValue == null) {
      return;
    }

    weeklyPlanning[slotId] = removeAccompanimentFromPlanningValue(currentValue);
    checkedShoppingItems.clear();

    await saveData();
  }

  Future<void> selectRecipeForSlot(String slotId, Recipe recipe) async {
    weeklyPlanning[slotId] = buildRecipePlanningValue(recipeId: recipe.id);
    checkedShoppingItems.clear();

    await saveData();
  }

  Future<void> removeRecipeFromSlot(String slotId) async {
    weeklyPlanning.remove(slotId);
    checkedShoppingItems.clear();

    await saveData();
  }

  Future<void> resetWeek() async {
    weeklyPlanning.clear();
    checkedShoppingItems.clear();

    await saveData();
  }

  Future<FillPlanningResult> fillEmptySlotsRandomly() async {
    if (recipes.isEmpty) {
      return const FillPlanningResult(addedMealsCount: 0, hasRecipes: false);
    }

    final emptySlots = mealSlots.where((slot) {
      return !weeklyPlanning.containsKey(slot.id);
    }).toList();

    if (emptySlots.isEmpty) {
      return const FillPlanningResult(addedMealsCount: 0, hasRecipes: true);
    }

    final random = Random();

    final recipeUsageCounts = <String, int>{
      for (final recipe in recipes) recipe.id: 0,
    };

    for (final planningValue in weeklyPlanning.values) {
      for (final recipeId in getRecipeIdsFromPlanningValue(planningValue)) {
        if (recipeUsageCounts.containsKey(recipeId)) {
          recipeUsageCounts[recipeId] = recipeUsageCounts[recipeId]! + 1;
        }
      }
    }

    final shuffledEmptySlots = [...emptySlots]..shuffle(random);

    for (final slot in shuffledEmptySlots) {
      final selectedRecipe = chooseRecipeForSlot(
        slot: slot,
        recipeUsageCounts: recipeUsageCounts,
        random: random,
      );

      weeklyPlanning[slot.id] = selectedRecipe.id;
      recipeUsageCounts[selectedRecipe.id] =
          recipeUsageCounts[selectedRecipe.id]! + 1;
    }

    checkedShoppingItems.clear();

    await saveData();

    return FillPlanningResult(
      addedMealsCount: emptySlots.length,
      hasRecipes: true,
    );
  }

  Recipe chooseRecipeForSlot({
    required MealSlot slot,
    required Map<String, int> recipeUsageCounts,
    required Random random,
  }) {
    final shuffledRecipes = [...recipes]..shuffle(random);

    Recipe? bestRecipe;
    int? bestScore;

    for (final recipe in shuffledRecipes) {
      final score = getRecipeScoreForSlot(
        recipe: recipe,
        slot: slot,
        recipeUsageCounts: recipeUsageCounts,
      );

      if (bestRecipe == null || score < bestScore!) {
        bestRecipe = recipe;
        bestScore = score;
      }
    }

    return bestRecipe!;
  }

  int getRecipeScoreForSlot({
    required Recipe recipe,
    required MealSlot slot,
    required Map<String, int> recipeUsageCounts,
  }) {
    final usageCount = recipeUsageCounts[recipe.id] ?? 0;

    // La répartition reste la priorité principale.
    final usageScore = usageCount * 100;

    final typeScore = getRecipeTypePreferenceScore(recipe);

    final timeScore = isWeekendSlot(slot)
        ? getWeekendTimeScore(recipe)
        : getWeekdayTimeScore(recipe);

    final seasonalityScore = getSeasonalityPreferenceScore(recipe);

    return usageScore + typeScore + timeScore + seasonalityScore;
  }

  int getRecipeTypePreferenceScore(Recipe recipe) {
    final hasFullDishTag = recipe.tags.contains('Plat complet');
    final hasMainDishTag = recipe.tags.contains('Plat principal');
    final hasSideDishTag = recipe.tags.contains('Accompagnement');
    final hasStarterTag = recipe.tags.contains('Entrée');
    final hasDessertTag = recipe.tags.contains('Dessert');

    if (hasFullDishTag) {
      return -35;
    }

    if (hasMainDishTag) {
      return -25;
    }

    if (!hasSideDishTag && !hasStarterTag && !hasDessertTag) {
      return 10;
    }

    return 80;
  }

  bool isWeekendSlot(MealSlot slot) {
    return slot.day == 'Samedi' || slot.day == 'Dimanche';
  }

  int getWeekdayTimeScore(Recipe recipe) {
    final prepTime = recipe.prepTimeMinutes ?? recipe.durationMinutes ?? 30;

    if (prepTime <= 20) {
      return -12;
    }

    if (prepTime <= 30) {
      return 0;
    }

    if (prepTime <= 45) {
      return 18;
    }

    return 35;
  }

  int getWeekendTimeScore(Recipe recipe) {
    final prepTime = recipe.prepTimeMinutes ?? recipe.durationMinutes ?? 30;
    final cookTime = recipe.cookTimeMinutes ?? 0;
    final totalTime = recipe.durationMinutes ?? prepTime;

    var score = 0;

    if (totalTime >= 60 || cookTime >= 45) {
      score -= 12;
    } else if (totalTime >= 40) {
      score -= 6;
    }

    if (prepTime > 60) {
      score += 10;
    }

    return score;
  }

  int getSeasonalityPreferenceScore(Recipe recipe) {
    final seasonality = SeasonalityService.analyzeRecipe(recipe);

    if (!seasonality.hasProduceIngredients) {
      return 0;
    }

    if (seasonality.isFullySeasonal) {
      return -18;
    }

    if (seasonality.score >= 50) {
      return -6;
    }

    return 8;
  }

  Future<void> toggleShoppingItem(String ingredient, bool isChecked) async {
    if (isChecked) {
      checkedShoppingItems.add(ingredient);
    } else {
      checkedShoppingItems.remove(ingredient);
    }

    await saveData();
  }
}
