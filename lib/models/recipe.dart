import '../data/recipe_difficulties.dart';
import '../data/recipe_emojis.dart';
import 'ingredient.dart';

class Recipe {
const Recipe({
  required this.id,
  required this.name,
  required this.ingredients,
  required this.steps,
  this.tags = const [],
  this.prepTimeMinutes,
  this.cookTimeMinutes,
  this.difficulty = defaultRecipeDifficulty,
  this.emoji = defaultRecipeEmoji,
  this.isFavorite = false,
});

  final String id;
  final String name;
  final List<Ingredient> ingredients;
  final String steps;
  final List<String> tags;


  /// Temps actif : découper, mélanger, préparer, surveiller activement.
  final int? prepTimeMinutes;

  /// Temps passif : cuisson, mijotage, four, repos.
  final int? cookTimeMinutes;

  final String difficulty;
  final String emoji;
  final bool isFavorite;
  
  
  
  /// Compatibilité avec les anciens écrans / anciennes données.
  /// Le total est calculé automatiquement.
  int? get durationMinutes {
    final prep = prepTimeMinutes ?? 0;
    final cook = cookTimeMinutes ?? 0;
    final total = prep + cook;

    if (total == 0) {
      return null;
    }

    return total;
  }

Recipe copyWith({
  String? id,
  String? name,
  List<Ingredient>? ingredients,
  String? steps,
  List<String>? tags,
  int? prepTimeMinutes,
  int? cookTimeMinutes,
  String? difficulty,
  String? emoji,
  bool? isFavorite,
}) {
  return Recipe(
    id: id ?? this.id,
    name: name ?? this.name,
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    tags: tags ?? this.tags,
    prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
    cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
    difficulty: difficulty ?? this.difficulty,
    emoji: emoji ?? this.emoji,
    isFavorite: isFavorite ?? this.isFavorite,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ingredients': ingredients.map((ingredient) => ingredient.toJson()).toList(),
      'steps': steps,
      'tags': tags,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'difficulty': difficulty,
      'emoji': emoji,
      'isFavorite': isFavorite,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'] as List? ?? [];

    final ingredients = rawIngredients.map((item) {
      if (item is String) {
        return Ingredient(name: item);
      }

      return Ingredient.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();

    final rawLegacyDuration = json['durationMinutes'];
    final rawPrepTime = json['prepTimeMinutes'];
    final rawCookTime = json['cookTimeMinutes'];

    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      ingredients: ingredients,
      steps: json['steps'] as String,
      tags: List<String>.from(json['tags'] as List? ?? []),

      // Migration douce :
      // si l’ancienne durée existe, on la met en temps de préparation.
      prepTimeMinutes: rawPrepTime == null
          ? rawLegacyDuration == null
              ? null
              : (rawLegacyDuration as num).toInt()
          : (rawPrepTime as num).toInt(),

      cookTimeMinutes: rawCookTime == null ? null : (rawCookTime as num).toInt(),
      difficulty: json['difficulty'] as String? ?? defaultRecipeDifficulty,
      emoji: json['emoji'] as String? ?? defaultRecipeEmoji,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  String formatMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h${remainingMinutes.toString().padLeft(2, '0')}';
  }

  String get prepTimeText {
    final prep = prepTimeMinutes;

    if (prep == null) {
      return '';
    }

    return '${formatMinutes(prep)} préparation';
  }

  String get cookTimeText {
    final cook = cookTimeMinutes;

    if (cook == null) {
      return '';
    }

    return '${formatMinutes(cook)} cuisson';
  }

  String get durationText {
    final total = durationMinutes;

    if (total == null) {
      return '';
    }

    return '${formatMinutes(total)} total';
  }

  String get difficultyText {
    if (difficulty == defaultRecipeDifficulty) {
      return '';
    }

    return difficulty;
  }

  String get timeSummaryText {
    final parts = <String>[];

    if (prepTimeText.isNotEmpty) {
      parts.add(prepTimeText);
    }

    if (cookTimeText.isNotEmpty) {
      parts.add(cookTimeText);
    }

    return parts.join(' • ');
  }

  String get metadataText {
    final parts = <String>[];

    if (timeSummaryText.isNotEmpty) {
      parts.add(timeSummaryText);
    }

    if (difficultyText.isNotEmpty) {
      parts.add(difficultyText);
    }

    return parts.join(' • ');
  }
}