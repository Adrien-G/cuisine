import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/ingredient_categories.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/unit_converter.dart';
import '../data/planning_entries.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({
    super.key,
    required this.recipes,
    required this.weeklyPlanning,
    required this.checkedShoppingItems,
    required this.onToggleItem,
    required this.onGoToPlanning,
  });

  final List<Recipe> recipes;
  final Map<String, String> weeklyPlanning;
  final Set<String> checkedShoppingItems;
  final Future<void> Function(String ingredient, bool isChecked) onToggleItem;
  final VoidCallback onGoToPlanning;

  Recipe? getRecipeById(String recipeId) {
    for (final recipe in recipes) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }

    return null;
  }

  Map<String, ShoppingItem> buildShoppingItems() {
    final Map<String, ShoppingItem> shoppingItems = {};

for (final planningValue in weeklyPlanning.values) {
  for (final recipeId in getRecipeIdsFromPlanningValue(planningValue)) {
    final recipe = getRecipeById(recipeId);

    if (recipe == null) {
      continue;
    }

    for (final ingredient in recipe.ingredients) {
      if (!ingredient.includeInShoppingList) {
        continue;
      }

      final normalizedName = ingredient.name.trim();

      if (normalizedName.isEmpty) {
        continue;
      }

      final normalizedCategory = ingredient.category.trim().isEmpty
          ? defaultIngredientCategory
          : ingredient.category.trim();

      final normalizedUnit = UnitConverter.normalize(ingredient.unit);

      final key = '${normalizedCategory.toLowerCase()}|'
          '${normalizedName.toLowerCase()}|'
          '${normalizedUnit.groupKey}';

      final existingItem = shoppingItems[key];

      if (existingItem == null) {
        shoppingItems[key] = ShoppingItem.fromIngredient(
          key: key,
          ingredient: ingredient,
          category: normalizedCategory,
          normalizedUnit: normalizedUnit,
        );
      } else {
        existingItem.addIngredient(ingredient);
      }
    }
  }
}

    final sortedEntries = shoppingItems.entries.toList()
      ..sort((a, b) {
        final categoryComparison = getIngredientCategoryOrder(
          a.value.category,
        ).compareTo(
          getIngredientCategoryOrder(b.value.category),
        );

        if (categoryComparison != 0) {
          return categoryComparison;
        }

        return a.value.name.toLowerCase().compareTo(
              b.value.name.toLowerCase(),
            );
      });

    return Map.fromEntries(sortedEntries);
  }

  Map<String, List<ShoppingItem>> groupItemsByCategory(
    Map<String, ShoppingItem> shoppingItems,
  ) {
    final groupedItems = <String, List<ShoppingItem>>{};

    for (final item in shoppingItems.values) {
      groupedItems.putIfAbsent(item.category, () => []);
      groupedItems[item.category]!.add(item);
    }

    return groupedItems;
  }

  List<String> getOrderedCategories(
    Map<String, List<ShoppingItem>> groupedItems,
  ) {
    final knownCategories = ingredientCategories.where(
      groupedItems.containsKey,
    );

    final unknownCategories = groupedItems.keys.where(
      (category) => !ingredientCategories.contains(category),
    );

    return [
      ...knownCategories,
      ...unknownCategories,
    ];
  }

  int getSelectedMealsCount() {
    return weeklyPlanning.length;
  }

  String buildShareText(
    Map<String, List<ShoppingItem>> groupedItems,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('Liste de courses de la semaine');
    buffer.writeln();

    for (final category in getOrderedCategories(groupedItems)) {
      final items = groupedItems[category];

      if (items == null || items.isEmpty) {
        continue;
      }

      buffer.writeln(category);

      for (final item in items) {
        buffer.writeln('- ${item.displayText}');
      }

      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  Future<void> shareShoppingList(
    BuildContext context,
    Map<String, List<ShoppingItem>> groupedItems,
  ) async {
    final shareText = buildShareText(groupedItems);

    if (shareText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La liste de courses est vide.'),
        ),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'Liste de courses',
      ),
    );
  }

  IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Fruits & légumes':
        return Icons.eco_outlined;
      case 'Frais':
        return Icons.kitchen_outlined;
      case 'Épicerie':
        return Icons.local_grocery_store_outlined;
      case 'Viandes / poissons':
        return Icons.set_meal_outlined;
      case 'Surgelés':
        return Icons.ac_unit_outlined;
      case 'Boissons':
        return Icons.local_drink_outlined;
      case 'Hygiène / entretien':
        return Icons.cleaning_services_outlined;
      default:
        return Icons.shopping_basket_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shoppingItems = buildShoppingItems();
    final groupedItems = groupItemsByCategory(shoppingItems);
    final orderedCategories = getOrderedCategories(groupedItems);
    final selectedMealsCount = getSelectedMealsCount();

    if (weeklyPlanning.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _EmptyShoppingCard(
          title: 'Ton planning est vide',
          message:
              'Ajoute des recettes dans le planning pour générer automatiquement ta liste de courses.',
          buttonLabel: 'Remplir le planning',
          icon: Icons.shopping_basket_outlined,
          onPressed: onGoToPlanning,
        ),
      );
    }

    if (shoppingItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _EmptyShoppingCard(
          title: 'Aucun ingrédient',
          message: 'Les recettes choisies ne contiennent aucun ingrédient.',
          buttonLabel: '',
          icon: Icons.shopping_basket_outlined,
          onPressed: null,
        ),
      );
    }

    final checkedCount = shoppingItems.keys
        .where((key) => checkedShoppingItems.contains(key))
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ShoppingHeader(
          selectedMealsCount: selectedMealsCount,
          checkedCount: checkedCount,
          totalCount: shoppingItems.length,
          onShare: () async {
            await shareShoppingList(context, groupedItems);
          },
        ),
        const SizedBox(height: 16),
        for (final category in orderedCategories)
          _CategoryShoppingCard(
            category: category,
            icon: getCategoryIcon(category),
            items: groupedItems[category] ?? [],
            checkedShoppingItems: checkedShoppingItems,
            onToggleItem: onToggleItem,
          ),
      ],
    );
  }
}

class _ShoppingHeader extends StatelessWidget {
  const _ShoppingHeader({
    required this.selectedMealsCount,
    required this.checkedCount,
    required this.totalCount,
    required this.onShare,
  });

  final int selectedMealsCount;
  final int checkedCount;
  final int totalCount;
  final Future<void> Function() onShare;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = totalCount == 0 ? 0.0 : checkedCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 36,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 14),
          Text(
            'Liste de courses',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.onPrimaryContainer,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$selectedMealsCount repas planifié(s) • '
            '$checkedCount/$totalCount article(s) acheté(s)',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share),
              label: const Text('Partager'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryShoppingCard extends StatelessWidget {
  const _CategoryShoppingCard({
    required this.category,
    required this.icon,
    required this.items,
    required this.checkedShoppingItems,
    required this.onToggleItem,
  });

  final String category;
  final IconData icon;
  final List<ShoppingItem> items;
  final Set<String> checkedShoppingItems;
  final Future<void> Function(String ingredient, bool isChecked) onToggleItem;

  @override
  Widget build(BuildContext context) {
    final checkedCount = items.where(
      (item) => checkedShoppingItems.contains(item.key),
    ).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryHeader(
              category: category,
              icon: icon,
              checkedCount: checkedCount,
              totalCount: items.length,
            ),
            const SizedBox(height: 10),
            for (final item in items)
              _ShoppingItemTile(
                item: item,
                isChecked: checkedShoppingItems.contains(item.key),
                onChanged: (value) async {
                  await onToggleItem(item.key, value);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.category,
    required this.icon,
    required this.checkedCount,
    required this.totalCount,
  });

  final String category;
  final IconData icon;
  final int checkedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _SmallBadge(
          label: '$checkedCount/$totalCount',
        ),
      ],
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.isChecked,
    required this.onChanged,
  });

  final ShoppingItem item;
  final bool isChecked;
  final Future<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isChecked
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await onChanged(!isChecked);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (value) async {
                    await onChanged(value ?? false);
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.displayText,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration:
                          isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (item.occurrences > 1)
                  _SmallBadge(
                    label: '${item.occurrences} repas',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyShoppingCard extends StatelessWidget {
  const _EmptyShoppingCard({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 38,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onPressed != null && buttonLabel.isNotEmpty) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(buttonLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShoppingItem {
  ShoppingItem({
    required this.key,
    required this.name,
    required this.category,
    required this.normalizedUnit,
    required this.baseQuantity,
    required this.occurrences,
    required this.hasUnquantifiedIngredient,
  });

  factory ShoppingItem.fromIngredient({
    required String key,
    required Ingredient ingredient,
    required String category,
    required NormalizedUnit normalizedUnit,
  }) {
    return ShoppingItem(
      key: key,
      name: ingredient.name.trim(),
      category: category,
      normalizedUnit: normalizedUnit,
      baseQuantity: ingredient.quantity == null
          ? null
          : normalizedUnit.convertToBase(ingredient.quantity!),
      occurrences: 1,
      hasUnquantifiedIngredient: ingredient.quantity == null,
    );
  }

  final String key;
  final String name;
  final String category;
  final NormalizedUnit normalizedUnit;

  double? baseQuantity;
  int occurrences;
  bool hasUnquantifiedIngredient;

  void addIngredient(Ingredient ingredient) {
    occurrences++;

    if (ingredient.quantity == null) {
      hasUnquantifiedIngredient = true;
      return;
    }

    final ingredientUnit = UnitConverter.normalize(ingredient.unit);
    final convertedQuantity = ingredientUnit.convertToBase(
      ingredient.quantity!,
    );

    baseQuantity = (baseQuantity ?? 0) + convertedQuantity;
  }

  String get displayText {
    final quantity = baseQuantity;

    if (quantity == null) {
      return name;
    }

    final quantityText = UnitConverter.formatBaseQuantity(
      normalizedUnit,
      quantity,
    );

    final text = '$quantityText $name';

    if (hasUnquantifiedIngredient) {
      return '$text + quantité non précisée';
    }

    return text;
  }
}