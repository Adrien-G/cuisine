import 'dart:math';
import 'package:flutter/material.dart';

import '../data/meal_slots.dart';
import '../data/planning_entries.dart';
import '../models/recipe.dart';
import '../services/storage_service.dart';
import '../services/seasonality_service.dart';
import 'recipe_form_screen.dart';
import 'planning_screen.dart';
import 'import_recipe_screen.dart';
import 'import_recipe_url_screen.dart';
import 'recipes_screen.dart';
import 'shopping_list_screen.dart';
import 'backup_screen.dart';

enum AddRecipeMode {
  manual,
  importText,
  importUrl,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storageService = StorageService();

  int selectedIndex = 0;
  bool isLoading = true;

  final List<Recipe> recipes = [];
  final Map<String, String> weeklyPlanning = {};
  final Set<String> checkedShoppingItems = {};

  final List<String> titles = const [
    'Mes recettes',
    'Planning de la semaine',
    'Liste de courses',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> openBackupScreen() async {
  final currentData = AppData(
    recipes: List<Recipe>.from(recipes),
    weeklyPlanning: Map<String, String>.from(weeklyPlanning),
    checkedShoppingItems: Set<String>.from(checkedShoppingItems),
  );

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) {
        return BackupScreen(
          appData: currentData,
          onRestoreData: restoreDataFromBackup,
        );
      },
    ),
  );
}

Future<void> restoreDataFromBackup(AppData importedData) async {
  setState(() {
    recipes.clear();
    recipes.addAll(importedData.recipes);

    weeklyPlanning.clear();
    weeklyPlanning.addAll(importedData.weeklyPlanning);

    checkedShoppingItems.clear();
    checkedShoppingItems.addAll(importedData.checkedShoppingItems);

    selectedIndex = 0;
  });

  await saveData();
}

  Future<void> loadData() async {
    final appData = await storageService.loadData();

    final migratedPlanning = migrateLegacyPlanning(appData.weeklyPlanning);
    final hasLegacyPlanning = containsLegacyPlanningKeys(
      appData.weeklyPlanning,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      recipes.clear();
      recipes.addAll(appData.recipes);

      weeklyPlanning.clear();
      weeklyPlanning.addAll(migratedPlanning);

      checkedShoppingItems.clear();
      checkedShoppingItems.addAll(appData.checkedShoppingItems);

      isLoading = false;
    });

    if (hasLegacyPlanning) {
      await saveData();
    }
  }

  Future<void> saveData() async {
    await storageService.saveData(
      recipes: recipes,
      weeklyPlanning: weeklyPlanning,
      checkedShoppingItems: checkedShoppingItems,
    );
  }

  void onDestinationSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

Future<void> openAddRecipeScreen() async {
  final selectedMode = await showModalBottomSheet<AddRecipeMode>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ajouter une recette',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Ajouter manuellement'),
                  subtitle: const Text(
                    'Créer une recette champ par champ.',
                  ),
                  onTap: () {
                    Navigator.of(context).pop(AddRecipeMode.manual);
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_fix_high_outlined),
                  title: const Text('Coller une recette'),
                  subtitle: const Text(
                    'Analyser un texte ou une liste d’ingrédients.',
                  ),
                  onTap: () {
                    Navigator.of(context).pop(AddRecipeMode.importText);
                  },
                ),
              ),
              Card(
  child: ListTile(
    leading: const Icon(Icons.link),
    title: const Text('Importer depuis un lien'),
    subtitle: const Text(
      'Pré-remplir depuis une page de recette compatible.',
    ),
    onTap: () {
      Navigator.of(context).pop(AddRecipeMode.importUrl);
    },
  ),
),
            ],
          ),
        ),
      );
    },
  );

 if (selectedMode == AddRecipeMode.manual) {
  await openManualRecipeForm();
  return;
}

if (selectedMode == AddRecipeMode.importText) {
  await openImportRecipeFlow();
  return;
}

await openImportRecipeUrlFlow();
}

Future<void> openImportRecipeUrlFlow() async {
  final draftRecipe = await Navigator.of(context).push<Recipe>(
    MaterialPageRoute(
      builder: (context) {
        return const ImportRecipeUrlScreen();
      },
    ),
  );

  if (draftRecipe == null) {
    return;
  }

  if (!mounted) {
    return;
  }

  final newRecipe = await Navigator.of(context).push<Recipe>(
    MaterialPageRoute(
      builder: (context) {
        return RecipeFormScreen(
          initialRecipe: draftRecipe,
          isDraft: true,
        );
      },
    ),
  );

  if (newRecipe == null) {
    return;
  }

  await addRecipe(newRecipe);
}

Future<void> openManualRecipeForm() async {
  final newRecipe = await Navigator.of(context).push<Recipe>(
    MaterialPageRoute(
      builder: (context) {
        return const RecipeFormScreen();
      },
    ),
  );

  if (newRecipe == null) {
    return;
  }

  await addRecipe(newRecipe);
}

Future<void> openImportRecipeFlow() async {
  final draftRecipe = await Navigator.of(context).push<Recipe>(
    MaterialPageRoute(
      builder: (context) {
        return const ImportRecipeScreen();
      },
    ),
  );

  if (draftRecipe == null) {
    return;
  }

  if (!mounted) {
    return;
  }

  final newRecipe = await Navigator.of(context).push<Recipe>(
    MaterialPageRoute(
      builder: (context) {
        return RecipeFormScreen(
          initialRecipe: draftRecipe,
          isDraft: true,
        );
      },
    ),
  );

  if (newRecipe == null) {
    return;
  }

  await addRecipe(newRecipe);
}

Future<void> toggleFavoriteRecipe(Recipe recipe) async {
  final recipeIndex = recipes.indexWhere((item) => item.id == recipe.id);

  if (recipeIndex == -1) {
    return;
  }

  final updatedRecipe = recipes[recipeIndex].copyWith(
    isFavorite: !recipes[recipeIndex].isFavorite,
  );

  setState(() {
    recipes[recipeIndex] = updatedRecipe;
  });

  await saveData();

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        updatedRecipe.isFavorite
            ? 'Recette ajoutée aux favoris.'
            : 'Recette retirée des favoris.',
      ),
    ),
  );
}
Future<void> addRecipe(Recipe newRecipe) async {
  setState(() {
    recipes.add(newRecipe);
  });

  await saveData();

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Recette ajoutée : ${newRecipe.name}'),
    ),
  );
}


Future<void> openEditRecipeScreen(Recipe recipeToEdit) async {
  final updatedRecipe = await Navigator.of(context).push<Recipe>(
    MaterialPageRoute(
      builder: (context) {
        return RecipeFormScreen(
          initialRecipe: recipeToEdit,
        );
      },
    ),
  );

  if (updatedRecipe == null) {
    return;
  }

  setState(() {
    final index = recipes.indexWhere(
      (recipe) => recipe.id == updatedRecipe.id,
    );

    if (index != -1) {
      recipes[index] = updatedRecipe;
    }

    checkedShoppingItems.clear();
  });

  await saveData();

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Recette modifiée : ${updatedRecipe.name}'),
    ),
  );
}

  Future<void> deleteRecipe(Recipe recipeToDelete) async {
    setState(() {
      recipes.removeWhere((recipe) => recipe.id == recipeToDelete.id);

      weeklyPlanning.removeWhere(
        (slotId, recipeId) => recipeId == recipeToDelete.id,
      );

      checkedShoppingItems.clear();
    });

    await saveData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recette supprimée : ${recipeToDelete.name}'),
      ),
    );
  }
Future<void> setSpecialMealForSlot(String slotId, String label) async {
  final specialMealLabel = label.trim().isEmpty
      ? defaultSpecialMealLabel
      : label.trim();

  setState(() {
    weeklyPlanning[slotId] = buildSpecialMealValue(specialMealLabel);
    checkedShoppingItems.clear();
  });

  await saveData();

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '$specialMealLabel ajouté pour ${getMealSlotLabel(slotId)}',
      ),
    ),
  );
}

Recipe? getRecipeById(String recipeId) {
  for (final recipe in recipes) {
    if (recipe.id == recipeId) {
      return recipe;
    }
  }

  return null;
}

Future<void> selectAccompanimentForSlot(
  String slotId,
  Recipe accompanimentRecipe,
) async {
  final currentValue = weeklyPlanning[slotId];
  final mainRecipeId = getMainRecipeIdFromPlanningValue(currentValue);

  if (mainRecipeId == null) {
    return;
  }

  final mainRecipe = getRecipeById(mainRecipeId);

  if (mainRecipe == null) {
    return;
  }

  if (mainRecipe.tags.contains('Plat complet')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ce plat est marqué comme plat complet : pas besoin d’accompagnement.',
        ),
      ),
    );
    return;
  }

  setState(() {
    weeklyPlanning[slotId] = buildRecipePlanningValue(
      recipeId: mainRecipeId,
      accompanimentRecipeId: accompanimentRecipe.id,
    );
    checkedShoppingItems.clear();
  });

  await saveData();

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Accompagnement ajouté : ${accompanimentRecipe.name}'),
    ),
  );
}

Future<void> removeAccompanimentFromSlot(String slotId) async {
  final currentValue = weeklyPlanning[slotId];

  if (currentValue == null) {
    return;
  }

  setState(() {
    weeklyPlanning[slotId] = removeAccompanimentFromPlanningValue(currentValue);
    checkedShoppingItems.clear();
  });

  await saveData();

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Accompagnement retiré.'),
    ),
  );
}

  Future<void> selectRecipeForSlot(String slotId, Recipe recipe) async {
    setState(() {
      weeklyPlanning[slotId] = buildRecipePlanningValue(
  recipeId: recipe.id,
);
      checkedShoppingItems.clear();
    });

    await saveData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${recipe.name} ajoutée pour ${getMealSlotLabel(slotId)}',
        ),
      ),
    );
  }

  Future<void> removeRecipeFromSlot(String slotId) async {
    setState(() {
      weeklyPlanning.remove(slotId);
      checkedShoppingItems.clear();
    });

    await saveData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recette retirée pour ${getMealSlotLabel(slotId)}',
        ),
      ),
    );
  }

  Future<void> resetWeek() async {
  setState(() {
    weeklyPlanning.clear();
    checkedShoppingItems.clear();
  });

  await saveData();

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('La semaine a été réinitialisée.'),
    ),
  );
}
  
 Future<void> fillEmptySlotsRandomly() async {
  if (recipes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ajoute au moins une recette avant de remplir le planning.',
        ),
      ),
    );
    return;
  }

  final emptySlots = mealSlots.where((slot) {
    return !weeklyPlanning.containsKey(slot.id);
  }).toList();

  if (emptySlots.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Le planning est déjà complet.'),
      ),
    );
    return;
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

  setState(() {
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
  });

  await saveData();

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${emptySlots.length} repas ajouté(s) avec un remplissage intelligent.',
      ),
    ),
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
  // Une recette déjà utilisée plusieurs fois devient nettement moins prioritaire.
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

  // Idéal pour un repas seul.
  if (hasFullDishTag) {
    return -35;
  }

  // Très bon choix aussi.
  if (hasMainDishTag) {
    return -25;
  }

  // Une recette sans type peut être ancienne ou non catégorisée.
  // On ne la bloque pas, mais elle passe après les recettes bien typées.
  if (!hasSideDishTag && !hasStarterTag && !hasDessertTag) {
    return 10;
  }

  // Ces recettes ne sont pas idéales seules dans un créneau repas.
  // Elles restent utilisables si l'app manque de choix.
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

  // Le week-end, on favorise un peu les recettes plus longues,
  // surtout si le temps long est de la cuisson passive.
  if (totalTime >= 60 || cookTime >= 45) {
    score -= 12;
  } else if (totalTime >= 40) {
    score -= 6;
  }

  // Même le week-end, une recette avec énormément de préparation active
  // reste un peu moins pratique.
  if (prepTime > 60) {
    score += 10;
  }

  return score;
}

int getSeasonalityPreferenceScore(Recipe recipe) {
  final seasonality = SeasonalityService.analyzeRecipe(recipe);

  // Important :
  // une recette sans fruit/légume ne doit pas être pénalisée.
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
    setState(() {
      if (isChecked) {
        checkedShoppingItems.add(ingredient);
      } else {
        checkedShoppingItems.remove(ingredient);
      }
    });

    await saveData();
  }

  void goToRecipes() {
    setState(() {
      selectedIndex = 0;
    });
  }

  void goToPlanning() {
    setState(() {
      selectedIndex = 1;
    });
  }

  Widget buildCurrentScreen() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    switch (selectedIndex) {
      case 0:
        return RecipesScreen(
  recipes: recipes,
  onAddRecipe: openAddRecipeScreen,
  onEditRecipe: openEditRecipeScreen,
  onDeleteRecipe: deleteRecipe,
  onToggleFavorite: toggleFavoriteRecipe,
);
      case 1:
        return PlanningScreen(
  recipes: recipes,
  weeklyPlanning: weeklyPlanning,
  onSelectRecipe: selectRecipeForSlot,
  onSetSpecialMeal: setSpecialMealForSlot,
  onRemoveRecipe: removeRecipeFromSlot,
  onResetWeek: resetWeek,
  onFillEmptySlots: fillEmptySlotsRandomly,
  onSelectAccompaniment: selectAccompanimentForSlot,
onRemoveAccompaniment: removeAccompanimentFromSlot,
  onGoToRecipes: goToRecipes,
);
      case 2:
        return ShoppingListScreen(
          recipes: recipes,
          weeklyPlanning: weeklyPlanning,
          checkedShoppingItems: checkedShoppingItems,
          onToggleItem: toggleShoppingItem,
          onGoToPlanning: goToPlanning,
        );
      default:
        return RecipesScreen(
  recipes: recipes,
  onAddRecipe: openAddRecipeScreen,
  onEditRecipe: openEditRecipeScreen,
  onDeleteRecipe: deleteRecipe,
  onToggleFavorite: toggleFavoriteRecipe,
);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
  title: Text(titles[selectedIndex]),
  centerTitle: true,
  actions: [
    IconButton(
      tooltip: 'Sauvegarde',
      onPressed: isLoading ? null : openBackupScreen,
      icon: const Icon(Icons.backup_outlined),
    ),
  ],
),
      body: buildCurrentScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Recettes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Planning',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart),
            label: 'Courses',
          ),
        ],
      ),
    );
  }
}