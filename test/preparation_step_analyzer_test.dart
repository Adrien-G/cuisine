import 'package:cuisine/services/preparation_step_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detecte les preparations implicites frequentes', () {
    final suggestions = PreparationStepAnalyzer.findImplicitPreparations(
      ingredientNames: const ['tomates', 'oignon', 'fromage'],
      steps: const [
        'Ajouter les tomates coupées en quartiers dans la préparation.',
        'Faire revenir avec l’oignon émincé.',
        'Parsemer de fromage râpé.',
      ],
    );

    expect(
      suggestions.map((suggestion) => suggestion.text),
      containsAll([
        'Couper les tomates en quartiers',
        'Émincer l’oignon',
        'Râper le fromage',
      ]),
    );
  });

  test('ne propose pas une preparation deja presente', () {
    final suggestions = PreparationStepAnalyzer.findImplicitPreparations(
      ingredientNames: const ['tomates'],
      steps: const [
        'Couper les tomates en quartiers.',
        'Ajouter les tomates coupées en quartiers dans la préparation.',
      ],
    );

    expect(suggestions, isEmpty);
  });

  test('genere une etape de preparations prealables', () {
    const suggestions = [
      PreparationStepSuggestion(text: 'Couper les tomates'),
      PreparationStepSuggestion(text: 'Émincer l’oignon'),
    ];

    expect(
      PreparationStepAnalyzer.buildPreparationStep(suggestions),
      'Préparations préalables :\n'
      '- Couper les tomates\n'
      '- Émincer l’oignon',
    );
  });
}
