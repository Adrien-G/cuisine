import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/recipe.dart';

class CookingStep {
  const CookingStep({required this.title, required this.text});

  final String title;
  final String text;
}

class CookingScreen extends StatefulWidget {
  const CookingScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  int currentStepIndex = 0;

  late final ConfettiController confettiController;

  Timer? countdownTimer;
  Duration timerDuration = Duration.zero;
  Duration remainingTimerDuration = Duration.zero;
  String timerLabel = '';
  bool isTimerRunning = false;
  bool hasTimerFinished = false;

  List<String> get recipePreparationSteps {
    final cleanedSteps = widget.recipe.steps.trim();

    if (cleanedSteps.isEmpty || cleanedSteps == 'À compléter.') {
      return [];
    }

    if (RegExp(r'\n\s*\n').hasMatch(cleanedSteps)) {
      return cleanedSteps
          .split(RegExp(r'\n\s*\n'))
          .map(cleanPreparationStepBlock)
          .where((step) => step.isNotEmpty && step != 'À compléter.')
          .toList();
    }

    final hasBulletList = RegExp(r'(^|\n)\s*[-•*]\s+').hasMatch(cleanedSteps);

    if (hasBulletList) {
      return [cleanPreparationStepBlock(cleanedSteps)];
    }

    return cleanedSteps
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
        text:
            'Lave-toi soigneusement les mains avant de commencer la préparation.',
      ),
      for (final step in recipePreparationSteps)
        CookingStep(title: 'Préparation', text: step),
    ];
  }

  bool get hasSteps => cookingSteps.isNotEmpty;

  bool get canGoPrevious => currentStepIndex > 0;

  bool get isLastStep => currentStepIndex == cookingSteps.length - 1;

  double get progress {
    if (!hasSteps) {
      return 0;
    }

    return (currentStepIndex + 1) / cookingSteps.length;
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
    countdownTimer?.cancel();
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

  String cleanPreparationStepBlock(String value) {
    return value.trim().replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
  }

  void setTimer({required Duration duration, required String label}) {
    countdownTimer?.cancel();

    setState(() {
      timerDuration = duration;
      remainingTimerDuration = duration;
      timerLabel = label.trim();
      isTimerRunning = false;
      hasTimerFinished = false;
    });
  }

  void setAndStartTimer({required Duration duration, required String label}) {
    setTimer(duration: duration, label: label);

    if (duration.inSeconds > 0) {
      startTimerWithDuration(duration);
    }
  }

  void startTimerWithDuration(Duration duration) {
    if (duration.inSeconds <= 0) {
      return;
    }

    countdownTimer?.cancel();

    setState(() {
      remainingTimerDuration = duration;
      isTimerRunning = true;
      hasTimerFinished = false;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTimerDuration.inSeconds <= 1) {
        timer.cancel();

        if (!mounted) {
          return;
        }

        setState(() {
          remainingTimerDuration = Duration.zero;
          isTimerRunning = false;
          hasTimerFinished = true;
        });

        showTimerFinishedDialog();
        return;
      }

      setState(() {
        remainingTimerDuration -= const Duration(seconds: 1);
      });
    });
  }

  void resetTimer() {
    countdownTimer?.cancel();

    setState(() {
      remainingTimerDuration = timerDuration;
      isTimerRunning = false;
      hasTimerFinished = false;
    });
  }

  Future<void> openTimerSettings() async {
    final settings = await showDialog<_TimerSettings>(
      context: context,
      builder: (context) {
        return _TimerSettingsDialog(
          initialDuration: timerDuration,
          initialLabel: timerLabel,
        );
      },
    );

    if (settings == null) {
      return;
    }

    setAndStartTimer(duration: settings.duration, label: settings.label);
  }

  Future<void> showTimerFinishedDialog() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final title = timerLabel.trim().isEmpty ? 'Minuteur' : timerLabel;

        return AlertDialog(
          title: const Text('Minuteur terminé'),
          content: Text('$title est terminé.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
    if (isLastStep) {
      finishCooking();
      return;
    }

    setState(() {
      currentStepIndex++;
    });
  }

  Future<void> finishCooking() async {
    countdownTimer?.cancel();
    confettiController.play();

    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) {
      return;
    }

    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('🎉 Bravo !'),
          content: Text('La recette "${widget.recipe.name}" est terminée.'),
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
      appBar: AppBar(title: const Text('Préparation')),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _CookingHeader(
                  recipe: widget.recipe,
                  currentStepIndex: currentStepIndex,
                  totalSteps: steps.length,
                  progress: progress,
                ),
                const SizedBox(height: 16),
                _IngredientsCard(recipe: widget.recipe),
                const SizedBox(height: 16),
                if (!hasSteps)
                  const _NoStepsCard()
                else
                  _CurrentStepCard(
                    stepNumber: currentStepIndex + 1,
                    stepTitle: steps[currentStepIndex].title,
                    stepText: steps[currentStepIndex].text,
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
      bottomNavigationBar: hasSteps
          ? _CookingFooter(
              timer: _StepTimerBar(
                label: timerLabel,
                duration: timerDuration,
                remainingDuration: remainingTimerDuration,
                isRunning: isTimerRunning,
                hasFinished: hasTimerFinished,
                onOpenSettings: openTimerSettings,
                onReset: resetTimer,
              ),
              navigation: _CookingNavigation(
                canGoPrevious: canGoPrevious,
                isLastStep: isLastStep,
                onPrevious: goPrevious,
                onNext: goNext,
              ),
            )
          : null,
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
                child: Text(recipe.emoji, style: const TextStyle(fontSize: 36)),
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
                backgroundColor: colorScheme.surface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({required this.recipe});

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
          style: TextStyle(fontWeight: FontWeight.w800),
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
    required this.stepTitle,
    required this.stepText,
  });

  final int stepNumber;
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

class _CookingFooter extends StatelessWidget {
  const _CookingFooter({required this.timer, required this.navigation});

  final Widget timer;
  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [timer, const SizedBox(height: 8), navigation],
          ),
        ),
      ),
    );
  }
}

class _StepTimerBar extends StatelessWidget {
  const _StepTimerBar({
    required this.label,
    required this.duration,
    required this.remainingDuration,
    required this.isRunning,
    required this.hasFinished,
    required this.onOpenSettings,
    required this.onReset,
  });

  final String label;
  final Duration duration;
  final Duration remainingDuration;
  final bool isRunning;
  final bool hasFinished;
  final VoidCallback onOpenSettings;
  final VoidCallback onReset;

  String formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDuration = duration.inSeconds > 0;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpenSettings,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.trim().isEmpty ? statusText(hasDuration) : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatDuration(remainingDuration),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: getTimerColor(
                          hasDuration: hasDuration,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Réinitialiser',
                onPressed: hasDuration ? onReset : null,
                icon: const Icon(Icons.refresh),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get hasTimerFinishedText => hasFinished ? 'Terminé' : 'Prêt';

  String statusText(bool hasDuration) {
    if (!hasDuration) {
      return 'Toucher pour régler';
    }

    if (isRunning) {
      return 'En cours';
    }

    return hasTimerFinishedText;
  }

  Color getTimerColor({
    required bool hasDuration,
    required ColorScheme colorScheme,
  }) {
    if (!hasDuration) {
      return colorScheme.onSurfaceVariant;
    }

    if (hasFinished) {
      return colorScheme.error;
    }

    return colorScheme.onSurface;
  }
}

class _TimerSettings {
  const _TimerSettings({required this.duration, required this.label});

  final Duration duration;
  final String label;
}

class _TimerSettingsDialog extends StatefulWidget {
  const _TimerSettingsDialog({
    required this.initialDuration,
    required this.initialLabel,
  });

  final Duration initialDuration;
  final String initialLabel;

  @override
  State<_TimerSettingsDialog> createState() => _TimerSettingsDialogState();
}

class _TimerSettingsDialogState extends State<_TimerSettingsDialog> {
  late final TextEditingController minutesController;
  late final TextEditingController labelController;

  @override
  void initState() {
    super.initState();

    minutesController = TextEditingController(
      text: widget.initialDuration.inMinutes == 0
          ? ''
          : widget.initialDuration.inMinutes.toString(),
    );
    labelController = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    minutesController.dispose();
    labelController.dispose();

    super.dispose();
  }

  void submit() {
    final minutes = int.tryParse(minutesController.text.trim()) ?? 0;

    Navigator.of(context).pop(
      _TimerSettings(
        duration: minutes <= 0 ? Duration.zero : Duration(minutes: minutes),
        label: labelController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Régler le minuteur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: minutesController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Temps',
              suffixText: 'min',
            ),
            onSubmitted: (_) {
              submit();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'Libellé',
              hintText: 'Ex : Cuisson des pâtes',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: submit, child: const Text('Valider')),
      ],
    );
  }
}

class _CookingNavigation extends StatelessWidget {
  const _CookingNavigation({
    required this.canGoPrevious,
    required this.isLastStep,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canGoPrevious;
  final bool isLastStep;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

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
            onPressed: onNext,
            icon: Icon(isLastStep ? Icons.check : Icons.arrow_forward),
            label: Text(isLastStep ? 'Terminer' : 'Suivant'),
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
