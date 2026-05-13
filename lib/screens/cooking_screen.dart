import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../models/recipe.dart';

class CookingStep {
  const CookingStep({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;
}

class CookingScreen extends StatefulWidget {
  const CookingScreen({
    super.key,
    required this.recipe,
  });

  final Recipe recipe;

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  int currentStepIndex = 0;
late final ConfettiController confettiController;
List<String> get recipePreparationSteps {
  return widget.recipe.steps
      .split('\n')
      .map(cleanPreparationStep)
      .where((step) => step.isNotEmpty && step != 'À compléter.')
      .toList();
}

List<CookingStep> get cookingSteps {
  final ingredientLines = widget.recipe.ingredients
      .map((ingredient) => '• ${ingredient.displayText}')
      .join('\n');

  return [
    CookingStep(
      title: 'Rassembler les ingrédients',
      text: ingredientLines.isEmpty
          ? 'Prépare tous les ingrédients nécessaires avant de commencer.'
          : 'Prépare tous les ingrédients nécessaires :\n\n$ingredientLines',
    ),
    const CookingStep(
      title: 'Se laver les mains',
      text: 'Lave-toi soigneusement les mains avant de commencer la préparation.',
    ),
    for (final step in recipePreparationSteps)
      CookingStep(
        title: 'Préparation',
        text: step,
      ),
  ];
}

  @override
void initState() {
  super.initState();

  confettiController = ConfettiController(
    duration: const Duration(seconds: 10),
  );
}

@override
void dispose() {
  confettiController.dispose();

  super.dispose();
}

  String cleanPreparationStep(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^[-•*]\s*'), '')
        .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
        .trim();
  }

bool get hasSteps => cookingSteps.isNotEmpty;

bool get canGoPrevious => currentStepIndex > 0;

bool get canGoNext => currentStepIndex < cookingSteps.length - 1;

bool get isLastStep => currentStepIndex == cookingSteps.length - 1;

double get progress {
  if (!hasSteps) {
    return 0;
  }

  return (currentStepIndex + 1) / cookingSteps.length;
}

  void goPrevious() {
    if (!canGoPrevious) {
      return;
    }

    setState(() {
      currentStepIndex--;
    });
  }

  void goNext() {
    if (!canGoNext) {
      return;
    }

    setState(() {
      currentStepIndex++;
    });
  }

  Future<void> finishCooking() async {
  confettiController.play();

  await Future.delayed(
    const Duration(milliseconds: 2000),
  );

  if (!mounted) {
    return;
  }

  final shouldClose = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('🎉 Bravo !'),
        content: Text(
          'La recette "${widget.recipe.name}" est terminée.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Terminer'),
          ),
        ],
      );
    },
  );

  if (!mounted) {
    return;
  }

  if (shouldClose == true) {
    Navigator.of(context).pop();
  }
}

  @override
  Widget build(BuildContext context) {
    final steps = cookingSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Préparation'),
      ),
    body: Stack(
  children: [
    SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CookingHeader(
            recipe: widget.recipe,
            currentStepIndex: currentStepIndex,
            totalSteps: steps.length,
            progress: progress,
          ),
          const SizedBox(height: 16),
          _IngredientsCard(
            recipe: widget.recipe,
          ),
          const SizedBox(height: 16),
          if (!hasSteps)
            const _NoStepsCard()
          else
            _CurrentStepCard(
  stepNumber: currentStepIndex + 1,
  totalSteps: steps.length,
  stepTitle: steps[currentStepIndex].title,
  stepText: steps[currentStepIndex].text,
),
          const SizedBox(height: 16),
          if (hasSteps)
            _CookingNavigation(
              canGoPrevious: canGoPrevious,
              canGoNext: canGoNext,
              isLastStep: isLastStep,
              onPrevious: goPrevious,
              onNext: goNext,
              onFinish: finishCooking,
            ),
        ],
      ),
    ),
    Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        numberOfParticles: 28,
        gravity: 0.25,
      ),
    ),
  ],
),
    );
  }
}

class _CookingHeader extends StatelessWidget {
  const _CookingHeader({
    required this.recipe,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.progress,
  });

  final Recipe recipe;
  final int currentStepIndex;
  final int totalSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  recipe.emoji,
                  style: const TextStyle(
                    fontSize: 36,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    if (recipe.metadataText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        recipe.metadataText,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (totalSteps > 0) ...[
            const SizedBox(height: 18),
            Text(
              'Étape ${currentStepIndex + 1} sur $totalSteps',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colorScheme.surface.withOpacity(0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({
    required this.recipe,
  });

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.shopping_basket_outlined),
        title: const Text(
          'Ingrédients',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text('${recipe.ingredients.length} ingrédient(s)'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final ingredient in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    ingredient.includeInShoppingList
                        ? Icons.circle
                        : Icons.remove_shopping_cart_outlined,
                    size: ingredient.includeInShoppingList ? 8 : 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ingredient.displayText,
                      style: TextStyle(
                        color: ingredient.includeInShoppingList
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrentStepCard extends StatelessWidget {
const _CurrentStepCard({
  required this.stepNumber,
  required this.totalSteps,
  required this.stepTitle,
  required this.stepText,
});

  final int stepNumber;
  final int totalSteps;
  final String stepText;
  final String stepTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
  stepTitle,
  style: const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
  ),
),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              stepText,
              style: const TextStyle(
                fontSize: 22,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookingNavigation extends StatelessWidget {
  const _CookingNavigation({
    required this.canGoPrevious,
    required this.canGoNext,
    required this.isLastStep,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final bool canGoPrevious;
  final bool canGoNext;
  final bool isLastStep;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Précédent'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: isLastStep ? onFinish : onNext,
            icon: Icon(
              isLastStep ? Icons.check : Icons.arrow_forward,
            ),
            label: Text(
              isLastStep ? 'Terminer' : 'Suivant',
            ),
          ),
        ),
      ],
    );
  }
}

class _NoStepsCard extends StatelessWidget {
  const _NoStepsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Cette recette ne contient pas encore d’étapes de préparation.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}