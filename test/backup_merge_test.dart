import 'package:cuisine/controllers/cuisine_controller.dart';
import 'package:cuisine/models/ingredient.dart';
import 'package:cuisine/models/meal_history_entry.dart';
import 'package:cuisine/models/recipe.dart';
import 'package:cuisine/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fusionne les nouvelles donnees sans ecraser le planning local',
    () async {
      final storage = _FakeStorageService();
      final controller = CuisineController(storageService: storage);

      controller.recipes.add(
        const Recipe(
          id: 'local',
          name: 'Recette locale',
          ingredients: [Ingredient(name: 'riz')],
          steps: 'Cuire.',
        ),
      );
      controller.weeklyPlanning['lundi_soir'] = 'local';
      controller.pantryIngredientNames.add('sel');

      final importedData = AppData(
        recipes: const [
          Recipe(
            id: 'remote',
            name: 'Recette distante',
            ingredients: [Ingredient(name: 'pâtes')],
            steps: 'Cuire.',
          ),
        ],
        weeklyPlanning: const {'lundi_soir': 'remote', 'mardi_soir': 'remote'},
        checkedShoppingItems: const {},
        pantryIngredientNames: const ['poivre'],
        mealHistoryEntries: const [],
      );

      final result = await controller.mergeDataFromBackup(importedData);

      expect(result.addedRecipesCount, 1);
      expect(result.addedPlanningEntriesCount, 1);
      expect(controller.recipes.map((recipe) => recipe.id), contains('local'));
      expect(controller.recipes.map((recipe) => recipe.id), contains('remote'));
      expect(controller.weeklyPlanning, {
        'lundi_soir': 'local',
        'mardi_soir': 'remote',
      });
      expect(controller.pantryIngredientNames, containsAll(['sel', 'poivre']));
      expect(storage.saveCount, 1);
    },
  );

  test('met a jour une recette existante avec le meme identifiant', () async {
    final storage = _FakeStorageService();
    final controller = CuisineController(storageService: storage);

    controller.recipes.add(
      const Recipe(
        id: 'same',
        name: 'Ancien nom',
        ingredients: [Ingredient(name: 'riz')],
        steps: 'Cuire.',
      ),
    );

    final importedData = AppData(
      recipes: const [
        Recipe(
          id: 'same',
          name: 'Nouveau nom',
          ingredients: [Ingredient(name: 'riz')],
          steps: 'Cuire doucement.',
        ),
      ],
      weeklyPlanning: const {},
      checkedShoppingItems: const {},
      pantryIngredientNames: const [],
      mealHistoryEntries: const [],
    );

    final result = await controller.mergeDataFromBackup(importedData);

    expect(result.updatedRecipesCount, 1);
    expect(controller.recipes.single.name, 'Nouveau nom');
  });

  test('remplace le planning quand le mode de fusion le demande', () async {
    final storage = _FakeStorageService();
    final controller = CuisineController(storageService: storage);

    controller.weeklyPlanning['lundi_soir'] = 'local';

    final importedData = AppData(
      recipes: const [],
      weeklyPlanning: const {'mardi_soir': 'remote'},
      checkedShoppingItems: const {},
      pantryIngredientNames: const [],
      mealHistoryEntries: const [],
    );

    final result = await controller.mergeDataFromBackup(
      importedData,
      planningMode: MergePlanningMode.replace,
    );

    expect(result.addedPlanningEntriesCount, 1);
    expect(controller.weeklyPlanning, {'mardi_soir': 'remote'});
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
