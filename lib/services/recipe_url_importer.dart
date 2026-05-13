import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/ingredient.dart';
import '../models/recipe.dart';
import 'recipe_text_parser.dart';

class RecipeUrlImporter {
static Future<Recipe> importFromUrl(String url) async {
  final uri = Uri.tryParse(url.trim());

  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw const RecipeUrlImportException(
      'Le lien ne semble pas valide.',
    );
  }

  final response = await http.get(
    uri,
    headers: const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    },
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw RecipeUrlImportException(
      'Impossible de charger la page. Code HTTP : ${response.statusCode}.',
    );
  }

  final document = html_parser.parse(response.body);

  final scripts = document.querySelectorAll('script').where((script) {
    final type = script.attributes['type']?.toLowerCase() ?? '';

    return type.contains('ld+json');
  }).toList();

  if (scripts.isEmpty) {
    throw const RecipeUrlImportException(
      'Je n’ai trouvé aucune donnée structurée JSON-LD sur cette page.',
    );
  }

  for (final script in scripts) {
    final rawJson = script.text.trim();

    if (rawJson.isEmpty) {
      continue;
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(rawJson);
    } catch (error) {
      // Certains sites ont plusieurs scripts JSON-LD.
      // Si l’un est invalide, on essaie les suivants.
      continue;
    }

    final recipeData = _findRecipeData(decoded);

    if (recipeData == null) {
      continue;
    }

    // Important :
    // on ne met PAS ce build dans un try/catch silencieux.
    // Si la recette est trouvée mais que la transformation échoue,
    // on veut voir une vraie erreur plutôt qu’un faux “recette non trouvée”.
    return _buildRecipeFromJsonLd(recipeData);
  }

  throw const RecipeUrlImportException(
    'Je n’ai pas trouvé de recette structurée sur cette page. '
    'Tu peux utiliser le mode “Coller une recette” à la place.',
  );
}
  static Map<String, dynamic>? _findRecipeData(dynamic value) {
    if (value is List) {
      for (final item in value) {
        final result = _findRecipeData(item);

        if (result != null) {
          return result;
        }
      }

      return null;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);

      if (_isRecipeType(map['@type'])) {
        return map;
      }

      final graph = map['@graph'];

      if (graph != null) {
        final result = _findRecipeData(graph);

        if (result != null) {
          return result;
        }
      }

      for (final child in map.values) {
        final result = _findRecipeData(child);

        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

static bool _isRecipeType(dynamic type) {
  if (type is String) {
    final normalizedType = type
        .toLowerCase()
        .replaceAll('schema:', '')
        .trim();

    return normalizedType == 'recipe' ||
        normalizedType.endsWith('/recipe') ||
        normalizedType.contains('recipe');
  }

  if (type is List) {
    return type.any(_isRecipeType);
  }

  return false;
}

  static Recipe _buildRecipeFromJsonLd(Map<String, dynamic> data) {
    final name = _readString(data['name']) ?? 'Nouvelle recette';

    final ingredientTexts = _readStringList(data['recipeIngredient']);

    final ingredients = ingredientTexts
        .map(RecipeTextParser.parseIngredientLine)
        .where((ingredient) => ingredient.name.trim().isNotEmpty)
        .toList();

    final steps = _readInstructions(data['recipeInstructions']);

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      ingredients: ingredients.isEmpty
          ? [
              const Ingredient(
                name: 'À compléter',
              ),
            ]
          : ingredients,
      steps: steps.trim().isEmpty ? 'À compléter.' : steps.trim(),
      prepTimeMinutes: _parseIsoDurationToMinutes(data['prepTime']),
      cookTimeMinutes: _parseIsoDurationToMinutes(data['cookTime']),
    
    );
  }

  static String? _readString(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      final trimmed = value.trim();

      if (trimmed.isEmpty) {
        return null;
      }

      return trimmed;
    }

    return value.toString().trim();
  }

  static List<String> _readStringList(dynamic value) {
    if (value == null) {
      return [];
    }

    if (value is String) {
      return value
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }

    if (value is List) {
      return value
          .map(_readString)
          .whereType<String>()
          .where((line) => line.trim().isNotEmpty)
          .toList();
    }

    return [];
  }

  static String _readInstructions(dynamic value) {
    final lines = _extractInstructionLines(value);

    return lines.join('\n');
  }

  static List<String> _extractInstructionLines(dynamic value) {
    if (value == null) {
      return [];
    }

    if (value is String) {
      return value
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }

    if (value is List) {
      final lines = <String>[];

      for (final item in value) {
        lines.addAll(_extractInstructionLines(item));
      }

      return lines;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);

      final text = _readString(map['text']);

      if (text != null) {
        return [text];
      }

      final name = _readString(map['name']);

      if (name != null) {
        return [name];
      }

      final itemListElement = map['itemListElement'];

      if (itemListElement != null) {
        return _extractInstructionLines(itemListElement);
      }
    }

    return [];
  }

  static int? _parseIsoDurationToMinutes(dynamic value) {
    final rawValue = _readString(value);

    if (rawValue == null) {
      return null;
    }

    final match = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
      caseSensitive: false,
    ).firstMatch(rawValue);

    if (match == null) {
      return null;
    }

    final days = int.tryParse(match.group(1) ?? '') ?? 0;
    final hours = int.tryParse(match.group(2) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(3) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(4) ?? '') ?? 0;

    final totalMinutes = (days * 24 * 60) + (hours * 60) + minutes;

    if (seconds > 0 && totalMinutes == 0) {
      return 1;
    }

    if (totalMinutes == 0) {
      return null;
    }

    return totalMinutes;
  }
}

class RecipeUrlImportException implements Exception {
  const RecipeUrlImportException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}