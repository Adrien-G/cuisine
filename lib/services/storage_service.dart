import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/pantry_ingredients.dart';
import '../models/recipe.dart';

class AppData {
  const AppData({
    required this.recipes,
    required this.weeklyPlanning,
    required this.checkedShoppingItems,
    required this.pantryIngredientNames,
  });

  final List<Recipe> recipes;
  final Map<String, String> weeklyPlanning;
  final Set<String> checkedShoppingItems;
  final List<String> pantryIngredientNames;
}

class StorageService {
  static const recipesStorageKey = 'recipes';
  static const planningStorageKey = 'weeklyPlanning';
  static const checkedItemsStorageKey = 'checkedShoppingItems';
  static const pantryIngredientsStorageKey = 'pantryIngredientNames';

  Future<AppData> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedRecipes = prefs.getString(recipesStorageKey);
    final savedPlanning = prefs.getString(planningStorageKey);
    final savedCheckedItems = prefs.getStringList(checkedItemsStorageKey);
    final savedPantryIngredients = prefs.getStringList(
      pantryIngredientsStorageKey,
    );

    final List<Recipe> loadedRecipes = [];
    final Map<String, String> loadedPlanning = {};
    final Set<String> loadedCheckedItems = {};
    final loadedPantryIngredients = savedPantryIngredients == null
        ? normalizePantryIngredientNames(defaultPantryIngredientNames)
        : normalizePantryIngredientNames(savedPantryIngredients);

    if (savedRecipes != null) {
      final decodedRecipes = jsonDecode(savedRecipes) as List;

      for (final item in decodedRecipes) {
        loadedRecipes.add(Recipe.fromJson(item as Map<String, dynamic>));
      }
    }

    if (savedPlanning != null) {
      final decodedPlanning = jsonDecode(savedPlanning) as Map<String, dynamic>;

      for (final entry in decodedPlanning.entries) {
        loadedPlanning[entry.key] = entry.value as String;
      }
    }

    if (savedCheckedItems != null) {
      loadedCheckedItems.addAll(savedCheckedItems);
    }

    return AppData(
      recipes: loadedRecipes,
      weeklyPlanning: loadedPlanning,
      checkedShoppingItems: loadedCheckedItems,
      pantryIngredientNames: loadedPantryIngredients,
    );
  }

  Future<void> saveData({
    required List<Recipe> recipes,
    required Map<String, String> weeklyPlanning,
    required Set<String> checkedShoppingItems,
    required List<String> pantryIngredientNames,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final recipesJson = jsonEncode(
      recipes.map((recipe) => recipe.toJson()).toList(),
    );

    final planningJson = jsonEncode(weeklyPlanning);

    await prefs.setString(recipesStorageKey, recipesJson);
    await prefs.setString(planningStorageKey, planningJson);
    await prefs.setStringList(
      checkedItemsStorageKey,
      checkedShoppingItems.toList(),
    );
    await prefs.setStringList(
      pantryIngredientsStorageKey,
      normalizePantryIngredientNames(pantryIngredientNames),
    );
  }
}
